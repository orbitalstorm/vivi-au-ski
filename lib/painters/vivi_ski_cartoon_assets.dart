import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Vector Cartoon Emblems & Badges for `VIVI AU SKI : Descente Royale 3D` (`v1.0.0`).
///
/// Rendered via a 4-layer High-Detail Vector Cartoon protocol:
/// 1. `base-shadow`: Ground drop shadow + 3D extruded silhouette occlusion
/// 2. `main-body` (Layer A): Multi-stop cel-shaded fills with thick `#2B1105` outlines
/// 3. `main-body` (Layer B): Sub-assemblies, mechanical/heraldic details & variable line weights
/// 4. `specular-highlights`: Crisp hard-edged white specular highlights (`#FFFFFF`)
enum SkiCartoonEmblemKind {
  greenTrackBadge('assets/cartoon/ski_track_green.svg'),
  blueTrackBadge('assets/cartoon/ski_track_blue.svg'),
  blackGoldTrackBadge('assets/cartoon/ski_track_black_gold.svg'),
  skiTrophyCup('assets/cartoon/ski_trophy_cup.svg'),
  jumpTrickStar('assets/cartoon/ski_jump_star.svg'),
  accelerometerTilt('assets/cartoon/ski_accelerometer_tilt.svg'),
  turntableGallery('assets/cartoon/ski_turntable_gallery.svg'),
  playSkiTriangle('assets/cartoon/ski_play_triangle.svg');

  const SkiCartoonEmblemKind(this.svgAssetPath);

  final String svgAssetPath;
}

class SkiCartoonEmblemBadge extends StatelessWidget {
  const SkiCartoonEmblemBadge({
    super.key,
    required this.kind,
    this.size = 36.0,
  });

  final SkiCartoonEmblemKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SkiCartoonEmblemPainter(kind: kind),
      ),
    );
  }
}

class _SkiCartoonEmblemPainter extends CustomPainter {
  const _SkiCartoonEmblemPainter({required this.kind});

  final SkiCartoonEmblemKind kind;

  static const Color _kOutline = Color(0xFF2B1105);

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width * 0.5, size.height * 0.5);
    final double r = math.min(size.width, size.height) * 0.44;

    // Variable line weight hierarchy: outer silhouette, intermediate volume, micro surface
    final Paint stroke = Paint()
      ..color = _kOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, r * 0.13)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final Paint fineStroke = Paint()
      ..color = _kOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, r * 0.08)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final Paint microStroke = Paint()
      ..color = _kOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.75, r * 0.05)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // Layer 1 (Ground Drop Shadow)
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + r * 0.92),
        width: r * 1.44,
        height: r * 0.24,
      ),
      Paint()..color = _kOutline.withValues(alpha: 0.30),
    );

    switch (kind) {
      case SkiCartoonEmblemKind.greenTrackBadge:
        _paintGreenTrackBadge(
          canvas,
          center,
          r,
          stroke,
          fineStroke,
          microStroke,
        );
      case SkiCartoonEmblemKind.blueTrackBadge:
        _paintBlueTrackBadge(
          canvas,
          center,
          r,
          stroke,
          fineStroke,
          microStroke,
        );
      case SkiCartoonEmblemKind.blackGoldTrackBadge:
        _paintBlackGoldBadge(
          canvas,
          center,
          r,
          stroke,
          fineStroke,
          microStroke,
        );
      case SkiCartoonEmblemKind.skiTrophyCup:
        _paintTrophyCup(
          canvas,
          center,
          r,
          stroke,
          fineStroke,
          microStroke,
        );
      case SkiCartoonEmblemKind.jumpTrickStar:
        _paintJumpTrickStar(
          canvas,
          center,
          r,
          stroke,
          fineStroke,
          microStroke,
        );
      case SkiCartoonEmblemKind.accelerometerTilt:
        _paintAccelerometerTilt(
          canvas,
          center,
          r,
          stroke,
          fineStroke,
          microStroke,
        );
      case SkiCartoonEmblemKind.turntableGallery:
        _paintTurntableGallery(
          canvas,
          center,
          r,
          stroke,
          fineStroke,
          microStroke,
        );
      case SkiCartoonEmblemKind.playSkiTriangle:
        _paintPlayTriangle(
          canvas,
          center,
          r,
          stroke,
          fineStroke,
          microStroke,
        );
    }
  }

  /// 1. Écusson Piste Verte *Vallée Blossom*
  /// (Sapin enneigé souriant, soleil doré, fleur Blossom et ruban émeraude `#00E676`)
  void _paintGreenTrackBadge(
    Canvas canvas,
    Offset c,
    double r,
    Paint stroke,
    Paint fineStroke,
    Paint microStroke,
  ) {
    Path buildShield(Offset offset, double scale) {
      final double sr = r * scale;
      return Path()
        ..moveTo(offset.dx, offset.dy - sr * 0.94)
        ..lineTo(offset.dx + sr * 0.82, offset.dy - sr * 0.58)
        ..lineTo(offset.dx + sr * 0.70, offset.dy + sr * 0.30)
        ..quadraticBezierTo(
          offset.dx + sr * 0.38,
          offset.dy + sr * 0.74,
          offset.dx,
          offset.dy + sr * 0.90,
        )
        ..quadraticBezierTo(
          offset.dx - sr * 0.38,
          offset.dy + sr * 0.74,
          offset.dx - sr * 0.70,
          offset.dy + sr * 0.30,
        )
        ..lineTo(offset.dx - sr * 0.82, offset.dy - sr * 0.58)
        ..close();
    }

    // Layer 1: Extruded 3D shield shadow
    final Path shadowShield = buildShield(Offset(c.dx, c.dy + r * 0.08), 1.0);
    canvas.drawPath(
      shadowShield,
      Paint()..color = _kOutline.withValues(alpha: 0.42),
    );

    // Layer 2: Outer shield fill & inner emerald bevel
    final Path shield = buildShield(c, 1.0);
    canvas.drawPath(
      shield,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(c.dx, c.dy - r),
          Offset(c.dx, c.dy + r),
          const <Color>[
            Color(0xFF69F0AE),
            Color(0xFF00E676),
            Color(0xFF008E46),
          ],
          const <double>[0.0, 0.52, 1.0],
        ),
    );
    canvas.drawPath(shield, stroke);

    final Path innerShield = buildShield(c, 0.84);
    canvas.drawPath(
      innerShield,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(c.dx - r * 0.6, c.dy - r * 0.7),
          Offset(c.dx + r * 0.6, c.dy + r * 0.7),
          const <Color>[
            Color(0xFFB9F6CA),
            Color(0xFF00E676),
            Color(0xFF006935),
          ],
          const <double>[0.0, 0.45, 1.0],
        ),
    );
    canvas.drawPath(innerShield, microStroke);

    // Layer 3: Golden sun with rays (top-right)
    final Offset sunCenter = Offset(c.dx + r * 0.36, c.dy - r * 0.36);
    final Paint rayPaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, r * 0.07)
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 6; i++) {
      final double a = i * (math.pi / 3);
      canvas.drawLine(
        Offset(
          sunCenter.dx + math.cos(a) * r * 0.24,
          sunCenter.dy + math.sin(a) * r * 0.24,
        ),
        Offset(
          sunCenter.dx + math.cos(a) * r * 0.33,
          sunCenter.dy + math.sin(a) * r * 0.33,
        ),
        rayPaint,
      );
    }
    canvas.drawCircle(
      sunCenter,
      r * 0.21,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(sunCenter.dx - r * 0.05, sunCenter.dy - r * 0.05),
          r * 0.26,
          const <Color>[
            Color(0xFFFFFDE7),
            Color(0xFFFFD700),
            Color(0xFFFF8F00),
          ],
          const <double>[0.0, 0.65, 1.0],
        ),
    );
    canvas.drawCircle(sunCenter, r * 0.21, fineStroke);

    // Trunk of the pine tree
    final RRect trunk = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(c.dx - r * 0.02, c.dy + r * 0.36),
        width: r * 0.20,
        height: r * 0.26,
      ),
      Radius.circular(r * 0.04),
    );
    canvas.drawRRect(trunk, Paint()..color = const Color(0xFF8D5B3C));
    canvas.drawRRect(trunk, fineStroke);

    // Multi-tiered smiling pine tree
    final Paint pineFill = Paint()
      ..shader = ui.Gradient.linear(
        Offset(c.dx, c.dy - r * 0.55),
        Offset(c.dx, c.dy + r * 0.32),
        const <Color>[Color(0xFF43A047), Color(0xFF2E7D32), Color(0xFF1B5E20)],
        const <double>[0.0, 0.55, 1.0],
      );

    final Path lowerTier = Path()
      ..moveTo(c.dx - r * 0.02, c.dy - r * 0.14)
      ..lineTo(c.dx - r * 0.50, c.dy + r * 0.30)
      ..quadraticBezierTo(
        c.dx - r * 0.02,
        c.dy + r * 0.38,
        c.dx + r * 0.46,
        c.dy + r * 0.30,
      )
      ..close();
    canvas.drawPath(lowerTier, pineFill);
    canvas.drawPath(lowerTier, fineStroke);

    final Path upperTier = Path()
      ..moveTo(c.dx - r * 0.02, c.dy - r * 0.54)
      ..lineTo(c.dx - r * 0.40, c.dy + r * 0.04)
      ..quadraticBezierTo(
        c.dx - r * 0.02,
        c.dy + r * 0.12,
        c.dx + r * 0.36,
        c.dy + r * 0.04,
      )
      ..close();
    canvas.drawPath(upperTier, pineFill);
    canvas.drawPath(upperTier, fineStroke);

    // Scalloped snow cap on top of the pine tree
    final Path snowCap = Path()
      ..moveTo(c.dx - r * 0.02, c.dy - r * 0.54)
      ..lineTo(c.dx - r * 0.25, c.dy - r * 0.18)
      ..quadraticBezierTo(
        c.dx - r * 0.13,
        c.dy - r * 0.10,
        c.dx - r * 0.02,
        c.dy - r * 0.18,
      )
      ..quadraticBezierTo(
        c.dx + r * 0.09,
        c.dy - r * 0.10,
        c.dx + r * 0.21,
        c.dy - r * 0.18,
      )
      ..close();
    canvas.drawPath(snowCap, Paint()..color = Colors.white);
    canvas.drawPath(snowCap, microStroke);

    // Smiling cartoon face on the pine tree
    canvas.drawCircle(
      Offset(c.dx - r * 0.15, c.dy + r * 0.17),
      r * 0.05,
      Paint()..color = const Color(0xFFFF8A80),
    );
    canvas.drawCircle(
      Offset(c.dx + r * 0.11, c.dy + r * 0.17),
      r * 0.05,
      Paint()..color = const Color(0xFFFF8A80),
    );
    canvas.drawCircle(
      Offset(c.dx - r * 0.11, c.dy + r * 0.09),
      r * 0.03,
      Paint()..color = _kOutline,
    );
    canvas.drawCircle(
      Offset(c.dx + r * 0.07, c.dy + r * 0.09),
      r * 0.03,
      Paint()..color = _kOutline,
    );
    final Path smile = Path()
      ..moveTo(c.dx - r * 0.09, c.dy + r * 0.16)
      ..quadraticBezierTo(
        c.dx - r * 0.02,
        c.dy + r * 0.24,
        c.dx + r * 0.05,
        c.dy + r * 0.16,
      );
    canvas.drawPath(smile, microStroke);

    // Blossom 4-petal flower on top-left
    final Offset blossomCenter = Offset(c.dx - r * 0.42, c.dy - r * 0.26);
    final Path blossom = _buildFourPointStar(
      blossomCenter,
      r * 0.19,
      r * 0.07,
    );
    canvas.drawPath(blossom, Paint()..color = const Color(0xFFFFF9C4));
    canvas.drawPath(blossom, microStroke);
    canvas.drawCircle(
      blossomCenter,
      r * 0.05,
      Paint()..color = const Color(0xFFFF4081),
    );

    // Emerald Ribbon `#00E676` across the bottom
    final Path ribbon = Path()
      ..moveTo(c.dx - r * 0.72, c.dy + r * 0.46)
      ..quadraticBezierTo(
        c.dx,
        c.dy + r * 0.68,
        c.dx + r * 0.72,
        c.dy + r * 0.46,
      )
      ..lineTo(c.dx + r * 0.64, c.dy + r * 0.72)
      ..quadraticBezierTo(
        c.dx,
        c.dy + r * 0.94,
        c.dx - r * 0.64,
        c.dy + r * 0.72,
      )
      ..close();
    canvas.drawPath(
      ribbon,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(c.dx - r * 0.7, c.dy + r * 0.5),
          Offset(c.dx + r * 0.7, c.dy + r * 0.5),
          const <Color>[
            Color(0xFF00C853),
            Color(0xFF69F0AE),
            Color(0xFF00964B),
          ],
          const <double>[0.0, 0.5, 1.0],
        ),
    );
    canvas.drawPath(ribbon, fineStroke);

    // Layer 4: Crisp hard-edged white specular highlights
    final Path rimHighlight = Path()
      ..moveTo(c.dx - r * 0.66, c.dy - r * 0.48)
      ..lineTo(c.dx - r * 0.06, c.dy - r * 0.78)
      ..lineTo(c.dx - r * 0.08, c.dy - r * 0.68)
      ..lineTo(c.dx - r * 0.58, c.dy - r * 0.42)
      ..close();
    canvas.drawPath(
      rimHighlight,
      Paint()..color = Colors.white.withValues(alpha: 0.82),
    );
    canvas.drawCircle(
      Offset(sunCenter.dx - r * 0.06, sunCenter.dy - r * 0.06),
      r * 0.055,
      Paint()..color = Colors.white.withValues(alpha: 0.92),
    );
  }

  /// 2. Écusson Piste Bleue *Forêt d'Asnières*
  /// (Double sommet alpin azur `#29B6F6`, skis croisés dorés et sapins)
  void _paintBlueTrackBadge(
    Canvas canvas,
    Offset c,
    double r,
    Paint stroke,
    Paint fineStroke,
    Paint microStroke,
  ) {
    // Layer 1: Extruded circular shadow
    canvas.drawCircle(
      Offset(c.dx, c.dy + r * 0.07),
      r * 0.88,
      Paint()..color = _kOutline.withValues(alpha: 0.42),
    );

    // Crossed golden skis extending behind medallion
    for (final double angle in <double>[-0.64, 0.64]) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(angle);
      final RRect ski = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: r * 1.92,
          height: r * 0.20,
        ),
        Radius.circular(r * 0.10),
      );
      canvas.drawRRect(
        ski,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(-r * 0.9, 0),
            Offset(r * 0.9, 0),
            const <Color>[
              Color(0xFFFFF9C4),
              Color(0xFFFFD700),
              Color(0xFFE65100),
            ],
            const <double>[0.0, 0.55, 1.0],
          ),
      );
      canvas.drawRRect(ski, fineStroke);
      canvas.restore();
    }

    // Layer 2: Outer metallic ice bezel & inner `#29B6F6` azure medallion
    final Rect outerRect = Rect.fromCircle(center: c, radius: r * 0.84);
    canvas.drawOval(
      outerRect,
      Paint()
        ..shader = ui.Gradient.linear(
          outerRect.topLeft,
          outerRect.bottomRight,
          const <Color>[
            Color(0xFFFFFFFF),
            Color(0xFF81D4FA),
            Color(0xFF01579B),
          ],
          const <double>[0.0, 0.50, 1.0],
        ),
    );
    canvas.drawOval(outerRect, stroke);

    final Rect innerRect = Rect.fromCircle(center: c, radius: r * 0.70);
    canvas.drawOval(
      innerRect,
      Paint()
        ..shader = ui.Gradient.linear(
          innerRect.topCenter,
          innerRect.bottomCenter,
          const <Color>[
            Color(0xFF80D8FF),
            Color(0xFF29B6F6),
            Color(0xFF0277BD),
          ],
          const <double>[0.0, 0.55, 1.0],
        ),
    );
    canvas.drawOval(innerRect, fineStroke);

    // Layer 3: Double faceted alpine peaks (Asnières Twin Peaks)
    final Path leftPeakLit = Path()
      ..moveTo(c.dx - r * 0.58, c.dy + r * 0.34)
      ..lineTo(c.dx - r * 0.18, c.dy - r * 0.48)
      ..lineTo(c.dx - r * 0.18, c.dy + r * 0.34)
      ..close();
    canvas.drawPath(leftPeakLit, Paint()..color = Colors.white);

    final Path leftPeakShade = Path()
      ..moveTo(c.dx - r * 0.18, c.dy - r * 0.48)
      ..lineTo(c.dx + r * 0.18, c.dy + r * 0.34)
      ..lineTo(c.dx - r * 0.18, c.dy + r * 0.34)
      ..close();
    canvas.drawPath(leftPeakShade, Paint()..color = const Color(0xFF81D4FA));

    final Path rightPeakLit = Path()
      ..moveTo(c.dx - r * 0.02, c.dy + r * 0.34)
      ..lineTo(c.dx + r * 0.28, c.dy - r * 0.34)
      ..lineTo(c.dx + r * 0.28, c.dy + r * 0.34)
      ..close();
    canvas.drawPath(rightPeakLit, Paint()..color = const Color(0xFFE1F5FE));

    final Path rightPeakShade = Path()
      ..moveTo(c.dx + r * 0.28, c.dy - r * 0.34)
      ..lineTo(c.dx + r * 0.58, c.dy + r * 0.34)
      ..lineTo(c.dx + r * 0.28, c.dy + r * 0.34)
      ..close();
    canvas.drawPath(rightPeakShade, Paint()..color = const Color(0xFF29B6F6));

    final Path peaksOutline = Path()
      ..moveTo(c.dx - r * 0.58, c.dy + r * 0.34)
      ..lineTo(c.dx - r * 0.18, c.dy - r * 0.48)
      ..lineTo(c.dx + r * 0.06, c.dy + r * 0.06)
      ..lineTo(c.dx + r * 0.28, c.dy - r * 0.34)
      ..lineTo(c.dx + r * 0.58, c.dy + r * 0.34)
      ..close();
    canvas.drawPath(peaksOutline, fineStroke);

    // Crossed miniature golden skis inside the crest
    for (final double angle in <double>[-0.48, 0.48]) {
      canvas.save();
      canvas.translate(c.dx, c.dy + r * 0.14);
      canvas.rotate(angle);
      final RRect miniSki = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: r * 0.78,
          height: r * 0.11,
        ),
        Radius.circular(r * 0.055),
      );
      canvas.drawRRect(miniSki, Paint()..color = const Color(0xFFFFD700));
      canvas.drawRRect(miniSki, microStroke);
      canvas.restore();
    }

    // Flanking alpine pines (left & right)
    for (final double side in <double>[-1.0, 1.0]) {
      final double px = c.dx + side * r * 0.44;
      final Path pine = Path()
        ..moveTo(px, c.dy - r * 0.02)
        ..lineTo(px - r * 0.15, c.dy + r * 0.42)
        ..lineTo(px + r * 0.15, c.dy + r * 0.42)
        ..close();
      canvas.drawPath(pine, Paint()..color = const Color(0xFF00695C));
      canvas.drawPath(pine, microStroke);
    }

    // Layer 4: Crisp hard-edged white specular highlights
    final Path arcHighlight = Path()
      ..addArc(
        Rect.fromCircle(center: c, radius: r * 0.76),
        -math.pi * 0.82,
        math.pi * 0.38,
      );
    canvas.drawPath(
      arcHighlight,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, r * 0.07)
        ..strokeCap = StrokeCap.round,
    );
  }

  /// 3. Écusson Piste Noire Or *Cimes Vendôme*
  /// (Diamant noir/ébène et couronne or 24K `#FFD700` sous aurore boréale)
  void _paintBlackGoldBadge(
    Canvas canvas,
    Offset c,
    double r,
    Paint stroke,
    Paint fineStroke,
    Paint microStroke,
  ) {
    Path buildDiamond(Offset center, double rx, double ry) {
      return Path()
        ..moveTo(center.dx, center.dy - ry)
        ..lineTo(center.dx + rx, center.dy)
        ..lineTo(center.dx, center.dy + ry)
        ..lineTo(center.dx - rx, center.dy)
        ..close();
    }

    // Layer 1: Extruded diamond shadow
    canvas.drawPath(
      buildDiamond(Offset(c.dx, c.dy + r * 0.08), r * 0.90, r * 0.94),
      Paint()..color = _kOutline.withValues(alpha: 0.46),
    );

    // Layer 2: Outer 24K Gold Vendôme diamond frame
    final Path outerDiamond = buildDiamond(c, r * 0.90, r * 0.94);
    canvas.drawPath(
      outerDiamond,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(c.dx - r, c.dy - r),
          Offset(c.dx + r, c.dy + r),
          const <Color>[
            Color(0xFFFFF9C4),
            Color(0xFFFFD700),
            Color(0xFFB26A00),
          ],
          const <double>[0.0, 0.50, 1.0],
        ),
    );
    canvas.drawPath(outerDiamond, stroke);

    // Ebony / Black Diamond core
    final Path innerDiamond = buildDiamond(c, r * 0.74, r * 0.78);
    canvas.drawPath(
      innerDiamond,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(c.dx - r * 0.7, c.dy - r * 0.7),
          Offset(c.dx + r * 0.7, c.dy + r * 0.7),
          const <Color>[
            Color(0xFF37474F),
            Color(0xFF141E28),
            Color(0xFF05080C),
          ],
          const <double>[0.0, 0.50, 1.0],
        ),
    );
    canvas.drawPath(innerDiamond, fineStroke);

    // Layer 3: Aurora Borealis ribbon across upper night sky
    final Path aurora = Path()
      ..moveTo(c.dx - r * 0.46, c.dy - r * 0.10)
      ..quadraticBezierTo(
        c.dx - r * 0.18,
        c.dy - r * 0.42,
        c.dx + r * 0.04,
        c.dy - r * 0.26,
      )
      ..quadraticBezierTo(
        c.dx + r * 0.24,
        c.dy - r * 0.12,
        c.dx + r * 0.46,
        c.dy - r * 0.32,
      )
      ..lineTo(c.dx + r * 0.52, c.dy - r * 0.20)
      ..quadraticBezierTo(
        c.dx + r * 0.24,
        c.dy + r * 0.02,
        c.dx,
        c.dy - r * 0.14,
      )
      ..quadraticBezierTo(
        c.dx - r * 0.20,
        c.dy - r * 0.28,
        c.dx - r * 0.52,
        c.dy - r * 0.02,
      )
      ..close();
    canvas.drawPath(
      aurora,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(c.dx - r * 0.5, c.dy - r * 0.3),
          Offset(c.dx + r * 0.5, c.dy - r * 0.3),
          const <Color>[
            Color(0xFF00E676),
            Color(0xFF00E5FF),
            Color(0xFFE040FB),
          ],
          const <double>[0.0, 0.5, 1.0],
        ),
    );

    // Royal 24K Gold Crown `#FFD700`
    final Path crown = Path()
      ..moveTo(c.dx - r * 0.38, c.dy + r * 0.28)
      ..lineTo(c.dx - r * 0.46, c.dy - r * 0.14)
      ..lineTo(c.dx - r * 0.18, c.dy + r * 0.04)
      ..lineTo(c.dx, c.dy - r * 0.30)
      ..lineTo(c.dx + r * 0.18, c.dy + r * 0.04)
      ..lineTo(c.dx + r * 0.46, c.dy - r * 0.14)
      ..lineTo(c.dx + r * 0.38, c.dy + r * 0.28)
      ..close();
    canvas.drawPath(
      crown,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(c.dx, c.dy - r * 0.30),
          Offset(c.dx, c.dy + r * 0.30),
          const <Color>[
            Color(0xFFFFFDE7),
            Color(0xFFFFD700),
            Color(0xFFB26A00),
          ],
          const <double>[0.0, 0.55, 1.0],
        ),
    );
    canvas.drawPath(crown, fineStroke);

    // Crown pearls & central ruby jewel
    for (final Offset pearl in <Offset>[
      Offset(c.dx - r * 0.46, c.dy - r * 0.18),
      Offset(c.dx, c.dy - r * 0.34),
      Offset(c.dx + r * 0.46, c.dy - r * 0.18),
    ]) {
      canvas.drawCircle(pearl, r * 0.055, Paint()..color = const Color(0xFFFFF9C4));
      canvas.drawCircle(pearl, r * 0.055, microStroke);
    }
    canvas.drawCircle(
      Offset(c.dx, c.dy + r * 0.14),
      r * 0.06,
      Paint()..color = const Color(0xFFFF1744),
    );
    canvas.drawCircle(
      Offset(c.dx - r * 0.20, c.dy + r * 0.16),
      r * 0.045,
      Paint()..color = const Color(0xFF00E676),
    );
    canvas.drawCircle(
      Offset(c.dx + r * 0.20, c.dy + r * 0.16),
      r * 0.045,
      Paint()..color = const Color(0xFF29B6F6),
    );

    // Layer 4: Crisp hard-edged white specular highlights
    final Path facetGleam = Path()
      ..moveTo(c.dx, c.dy - r * 0.84)
      ..lineTo(c.dx + r * 0.07, c.dy - r * 0.77)
      ..lineTo(c.dx - r * 0.68, c.dy)
      ..lineTo(c.dx - r * 0.76, c.dy - r * 0.06)
      ..close();
    canvas.drawPath(
      facetGleam,
      Paint()..color = Colors.white.withValues(alpha: 0.82),
    );
    canvas.drawCircle(
      Offset(c.dx - r * 0.05, c.dy - r * 0.12),
      r * 0.04,
      Paint()..color = Colors.white.withValues(alpha: 0.92),
    );
  }

  /// 4. Coupe/Trophée d'Or Alpin Cartoon sertie de cristaux de neige et d'une étoile Monogram
  void _paintTrophyCup(
    Canvas canvas,
    Offset c,
    double r,
    Paint stroke,
    Paint fineStroke,
    Paint microStroke,
  ) {
    // Ice snow crystals crowning the rim
    final Paint crystalFill = Paint()
      ..shader = ui.Gradient.linear(
        Offset(c.dx, c.dy - r * 0.96),
        Offset(c.dx, c.dy - r * 0.56),
        const <Color>[Color(0xFFFFFFFF), Color(0xFF80D8FF), Color(0xFF0288D1)],
        const <double>[0.0, 0.55, 1.0],
      );
    for (final double dx in <double>[-0.24, 0.0, 0.24]) {
      final double topY = dx == 0.0 ? -0.96 : -0.86;
      final Path shard = Path()
        ..moveTo(c.dx + (dx - 0.12) * r, c.dy - r * 0.64)
        ..lineTo(c.dx + dx * r, c.dy + topY * r)
        ..lineTo(c.dx + (dx + 0.12) * r, c.dy - r * 0.64)
        ..close();
      canvas.drawPath(shard, crystalFill);
      canvas.drawPath(shard, microStroke);
    }

    // Twin scrolled golden handles
    for (final double side in <double>[-1.0, 1.0]) {
      final Path handle = Path()
        ..moveTo(c.dx + side * r * 0.46, c.dy - r * 0.50)
        ..cubicTo(
          c.dx + side * r * 0.92,
          c.dy - r * 0.56,
          c.dx + side * r * 0.92,
          c.dy + r * 0.02,
          c.dx + side * r * 0.36,
          c.dy + r * 0.06,
        );
      canvas.drawPath(
        handle,
        Paint()
          ..color = const Color(0xFFFFB300)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2.0, r * 0.15)
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawPath(handle, stroke);
    }

    // Turned golden stem & collar node
    final RRect stem = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(c.dx, c.dy + r * 0.42),
        width: r * 0.28,
        height: r * 0.36,
      ),
      Radius.circular(r * 0.06),
    );
    canvas.drawRRect(stem, Paint()..color = const Color(0xFFFFB300));
    canvas.drawRRect(stem, fineStroke);

    // Golden chalice cup body
    final Path cup = Path()
      ..moveTo(c.dx - r * 0.56, c.dy - r * 0.66)
      ..lineTo(c.dx + r * 0.56, c.dy - r * 0.66)
      ..lineTo(c.dx + r * 0.42, c.dy + r * 0.06)
      ..quadraticBezierTo(
        c.dx,
        c.dy + r * 0.42,
        c.dx - r * 0.42,
        c.dy + r * 0.06,
      )
      ..close();
    canvas.drawPath(
      cup,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(c.dx - r * 0.5, c.dy - r * 0.7),
          Offset(c.dx + r * 0.5, c.dy + r * 0.4),
          const <Color>[
            Color(0xFFFFFDE7),
            Color(0xFFFFD700),
            Color(0xFFC66900),
          ],
          const <double>[0.0, 0.48, 1.0],
        ),
    );
    canvas.drawPath(cup, stroke);

    // Upper moulded lip rim
    final RRect lipRim = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(c.dx, c.dy - r * 0.66),
        width: r * 1.20,
        height: r * 0.14,
      ),
      Radius.circular(r * 0.07),
    );
    canvas.drawRRect(lipRim, Paint()..color = const Color(0xFFFFF59D));
    canvas.drawRRect(lipRim, fineStroke);

    // Central Monogram Star & snow crystal medallion on the chalice
    final Offset starCenter = Offset(c.dx, c.dy - r * 0.22);
    final Path monogramStar = _buildFourPointStar(
      starCenter,
      r * 0.30,
      r * 0.11,
    );
    canvas.drawPath(monogramStar, crystalFill);
    canvas.drawPath(monogramStar, microStroke);
    canvas.drawCircle(
      starCenter,
      r * 0.06,
      Paint()..color = const Color(0xFFFFF9C4),
    );

    // Royal 2-tiered mahogany plinth base with gold nameplate
    final RRect plinthUpper = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(c.dx, c.dy + r * 0.60),
        width: r * 0.72,
        height: r * 0.16,
      ),
      Radius.circular(r * 0.05),
    );
    canvas.drawRRect(plinthUpper, Paint()..color = const Color(0xFF9E1F26));
    canvas.drawRRect(plinthUpper, fineStroke);

    final RRect base = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(c.dx, c.dy + r * 0.76),
        width: r * 0.94,
        height: r * 0.22,
      ),
      Radius.circular(r * 0.07),
    );
    canvas.drawRRect(base, Paint()..color = const Color(0xFF7B181E));
    canvas.drawRRect(base, stroke);

    final RRect nameplate = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(c.dx, c.dy + r * 0.76),
        width: r * 0.50,
        height: r * 0.10,
      ),
      Radius.circular(r * 0.03),
    );
    canvas.drawRRect(nameplate, Paint()..color = const Color(0xFFFFD700));
    canvas.drawRRect(nameplate, microStroke);

    // Layer 4: Crisp hard-edged white specular highlights
    final Path cupSpec = Path()
      ..moveTo(c.dx - r * 0.42, c.dy - r * 0.52)
      ..lineTo(c.dx - r * 0.28, c.dy - r * 0.52)
      ..lineTo(c.dx - r * 0.24, c.dy - r * 0.02)
      ..lineTo(c.dx - r * 0.34, c.dy - r * 0.06)
      ..close();
    canvas.drawPath(
      cupSpec,
      Paint()..color = Colors.white.withValues(alpha: 0.80),
    );
  }

  /// 5. Étoile Aérienne *Big Air Trick* avec traînée d'arc-en-ciel doré et flocons
  void _paintJumpTrickStar(
    Canvas canvas,
    Offset c,
    double r,
    Paint stroke,
    Paint fineStroke,
    Paint microStroke,
  ) {
    // Layer 2: Sweeping 3-band rainbow-gold motion trail
    final List<Color> trailColors = <Color>[
      const Color(0xFFFF4081),
      const Color(0xFFFFD700),
      const Color(0xFF29B6F6),
    ];
    for (int i = 0; i < 3; i++) {
      final double dy = i * r * 0.13;
      final Path band = Path()
        ..moveTo(c.dx - r * 0.82 + dy * 0.6, c.dy + r * 0.52 + dy * 0.5)
        ..quadraticBezierTo(
          c.dx - r * 0.42,
          c.dy - r * 0.08 + dy,
          c.dx + r * 0.14,
          c.dy - r * 0.22 + dy,
        )
        ..lineTo(c.dx + r * 0.20, c.dy - r * 0.08 + dy)
        ..quadraticBezierTo(
          c.dx - r * 0.28,
          c.dy + r * 0.08 + dy,
          c.dx - r * 0.68 + dy * 0.6,
          c.dy + r * 0.64 + dy * 0.4,
        )
        ..close();
      canvas.drawPath(band, Paint()..color = trailColors[i]);
      canvas.drawPath(band, microStroke);
    }

    // Layer 3: 5-pointed faceted Big Air Star (shifted slightly top-right)
    final Offset starCenter = Offset(c.dx + r * 0.14, c.dy - r * 0.10);
    final Path star = Path();
    for (int i = 0; i < 10; i++) {
      final double angle = -math.pi / 2 + i * (math.pi / 5);
      final double rad = i.isEven ? r * 0.78 : r * 0.34;
      final Offset p = Offset(
        starCenter.dx + math.cos(angle) * rad,
        starCenter.dy + math.sin(angle) * rad,
      );
      if (i == 0) {
        star.moveTo(p.dx, p.dy);
      } else {
        star.lineTo(p.dx, p.dy);
      }
    }
    star.close();

    // Extruded star shadow
    canvas.save();
    canvas.translate(r * 0.05, r * 0.07);
    canvas.drawPath(
      star,
      Paint()..color = _kOutline.withValues(alpha: 0.38),
    );
    canvas.restore();

    canvas.drawPath(
      star,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(starCenter.dx, starCenter.dy - r * 0.8),
          Offset(starCenter.dx, starCenter.dy + r * 0.8),
          const <Color>[
            Color(0xFFFFFDE7),
            Color(0xFFFFD700),
            Color(0xFFFF6F00),
          ],
          const <double>[0.0, 0.50, 1.0],
        ),
    );
    canvas.drawPath(star, stroke);

    // Inner Monogram core inside the Big Air star
    final Path innerCore = _buildFourPointStar(
      starCenter,
      r * 0.24,
      r * 0.08,
    );
    canvas.drawPath(innerCore, Paint()..color = const Color(0xFFFFFDE7));
    canvas.drawPath(innerCore, microStroke);

    // Surrounding geometric snowflakes
    for (final Offset flakePos in <Offset>[
      Offset(c.dx - r * 0.56, c.dy - r * 0.52),
      Offset(c.dx + r * 0.66, c.dy + r * 0.56),
    ]) {
      final Path flake = _buildFourPointStar(flakePos, r * 0.18, r * 0.05);
      canvas.drawPath(flake, Paint()..color = const Color(0xFFE1F5FE));
      canvas.drawPath(flake, microStroke);
    }

    // Layer 4: Crisp hard-edged white specular highlights
    final Path topGleam = Path()
      ..moveTo(starCenter.dx, starCenter.dy - r * 0.64)
      ..lineTo(starCenter.dx + r * 0.12, starCenter.dy - r * 0.30)
      ..lineTo(starCenter.dx - r * 0.10, starCenter.dy - r * 0.26)
      ..close();
    canvas.drawPath(
      topGleam,
      Paint()..color = Colors.white.withValues(alpha: 0.88),
    );
  }

  /// 6. Volant/Inclinomètre Téléphone Cartoon avec flèches de carving gauche/droite
  void _paintAccelerometerTilt(
    Canvas canvas,
    Offset c,
    double r,
    Paint stroke,
    Paint fineStroke,
    Paint microStroke,
  ) {
    // Layer 2: Bidirectional Left (Gold) & Right (Emerald) carving tilt arrows
    final Path leftArrow = Path()
      ..moveTo(c.dx - r * 0.10, c.dy - r * 0.78)
      ..quadraticBezierTo(
        c.dx - r * 0.68,
        c.dy - r * 0.72,
        c.dx - r * 0.82,
        c.dy - r * 0.20,
      )
      ..lineTo(c.dx - r * 0.94, c.dy - r * 0.24)
      ..lineTo(c.dx - r * 0.80, c.dy + r * 0.04)
      ..lineTo(c.dx - r * 0.56, c.dy - r * 0.12)
      ..lineTo(c.dx - r * 0.66, c.dy - r * 0.16)
      ..quadraticBezierTo(
        c.dx - r * 0.54,
        c.dy - r * 0.56,
        c.dx - r * 0.10,
        c.dy - r * 0.62,
      )
      ..close();
    canvas.drawPath(leftArrow, Paint()..color = const Color(0xFFFFD700));
    canvas.drawPath(leftArrow, fineStroke);

    final Path rightArrow = Path()
      ..moveTo(c.dx + r * 0.10, c.dy - r * 0.78)
      ..quadraticBezierTo(
        c.dx + r * 0.68,
        c.dy - r * 0.72,
        c.dx + r * 0.82,
        c.dy - r * 0.20,
      )
      ..lineTo(c.dx + r * 0.94, c.dy - r * 0.24)
      ..lineTo(c.dx + r * 0.80, c.dy + r * 0.04)
      ..lineTo(c.dx + r * 0.56, c.dy - r * 0.12)
      ..lineTo(c.dx + r * 0.66, c.dy - r * 0.16)
      ..quadraticBezierTo(
        c.dx + r * 0.54,
        c.dy - r * 0.56,
        c.dx + r * 0.10,
        c.dy - r * 0.62,
      )
      ..close();
    canvas.drawPath(rightArrow, Paint()..color = const Color(0xFF00E676));
    canvas.drawPath(rightArrow, fineStroke);

    // Layer 3: Tilted Smartphone Chassis & Gyroscope Horizon Screen
    canvas.save();
    canvas.translate(c.dx, c.dy + r * 0.12);
    canvas.rotate(-0.26);

    final RRect phoneShadow = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(r * 0.06, r * 0.08),
        width: r * 0.84,
        height: r * 1.32,
      ),
      Radius.circular(r * 0.18),
    );
    canvas.drawRRect(
      phoneShadow,
      Paint()..color = _kOutline.withValues(alpha: 0.36),
    );

    final RRect phone = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: r * 0.84, height: r * 1.32),
      Radius.circular(r * 0.18),
    );
    canvas.drawRRect(
      phone,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(-r * 0.4, -r * 0.6),
          Offset(r * 0.4, r * 0.6),
          const <Color>[Color(0xFF546E7A), Color(0xFF263238)],
        ),
    );
    canvas.drawRRect(phone, stroke);

    final RRect screen = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: r * 0.66, height: r * 1.02),
      Radius.circular(r * 0.10),
    );
    canvas.drawRRect(
      screen,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, -r * 0.5),
          Offset(0, r * 0.5),
          const <Color>[Color(0xFF80D8FF), Color(0xFF0288D1)],
        ),
    );
    canvas.drawRRect(screen, fineStroke);

    // Mini ski slope & gyroscope level indicator on screen
    final Path miniSlope = Path()
      ..moveTo(-r * 0.12, -r * 0.22)
      ..lineTo(r * 0.12, -r * 0.22)
      ..lineTo(r * 0.28, r * 0.48)
      ..lineTo(-r * 0.28, r * 0.48)
      ..close();
    canvas.drawPath(miniSlope, Paint()..color = const Color(0xFFE1F5FE));

    // Counter-rotated gyroscope level line & bubble
    canvas.save();
    canvas.rotate(0.26);
    canvas.drawLine(
      Offset(-r * 0.24, 0),
      Offset(r * 0.24, 0),
      Paint()
        ..color = const Color(0xFFFFD700)
        ..strokeWidth = math.max(1.2, r * 0.07)
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      Offset.zero,
      r * 0.11,
      Paint()..color = const Color(0xFF00E676),
    );
    canvas.drawCircle(Offset.zero, r * 0.11, microStroke);
    canvas.restore();

    // Layer 4: Crisp hard-edged white glass reflection bar
    final RRect glassSpec = RRect.fromRectAndRadius(
      Rect.fromLTWH(-r * 0.26, -r * 0.42, r * 0.09, r * 0.48),
      Radius.circular(r * 0.045),
    );
    canvas.drawRRect(
      glassSpec,
      Paint()..color = Colors.white.withValues(alpha: 0.78),
    );

    canvas.restore();
  }

  /// 7. Piédestal Rotatif 360° Or & Bois avec flèches orbitales
  void _paintTurntableGallery(
    Canvas canvas,
    Offset c,
    double r,
    Paint stroke,
    Paint fineStroke,
    Paint microStroke,
  ) {
    // Layer 2: Lower 24K Gold ring & Pearwood cylindrical plinth
    final Rect lowerGoldOval = Rect.fromCenter(
      center: Offset(c.dx, c.dy + r * 0.56),
      width: r * 1.56,
      height: r * 0.44,
    );
    canvas.drawOval(lowerGoldOval, Paint()..color = const Color(0xFFFFB300));
    canvas.drawOval(lowerGoldOval, stroke);

    final RRect woodCylinder = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(c.dx, c.dy + r * 0.40),
        width: r * 1.32,
        height: r * 0.32,
      ),
      Radius.circular(r * 0.12),
    );
    canvas.drawRRect(
      woodCylinder,
      Paint()
        ..shader = ui.Gradient.linear(
          woodCylinder.outerRect.centerLeft,
          woodCylinder.outerRect.centerRight,
          const <Color>[
            Color(0xFFF5CBA7),
            Color(0xFFE3A17B),
            Color(0xFF8D5B3C),
          ],
          const <double>[0.0, 0.50, 1.0],
        ),
    );
    canvas.drawRRect(woodCylinder, fineStroke);

    // Upper 24K Gold turntable disc & snow stage
    final Rect upperGoldOval = Rect.fromCenter(
      center: Offset(c.dx, c.dy + r * 0.26),
      width: r * 1.44,
      height: r * 0.42,
    );
    canvas.drawOval(
      upperGoldOval,
      Paint()
        ..shader = ui.Gradient.linear(
          upperGoldOval.centerLeft,
          upperGoldOval.centerRight,
          const <Color>[
            Color(0xFFFFF9C4),
            Color(0xFFFFD700),
            Color(0xFFC66900),
          ],
          const <double>[0.0, 0.50, 1.0],
        ),
    );
    canvas.drawOval(upperGoldOval, stroke);

    final Rect snowStage = Rect.fromCenter(
      center: Offset(c.dx, c.dy + r * 0.24),
      width: r * 1.06,
      height: r * 0.28,
    );
    canvas.drawOval(snowStage, Paint()..color = const Color(0xFFE1F5FE));
    canvas.drawOval(snowStage, microStroke);

    // Layer 3: Stylized Vivienne bust token on the turntable
    final Offset headCenter = Offset(c.dx, c.dy - r * 0.22);
    // Top & side Monogram petals
    for (final double a in <double>[-math.pi / 2, math.pi, 0.0]) {
      final Offset petalTip = Offset(
        headCenter.dx + math.cos(a) * r * 0.58,
        headCenter.dy + math.sin(a) * r * 0.58,
      );
      canvas.drawCircle(
        petalTip,
        r * 0.14,
        Paint()..color = const Color(0xFFFFD700),
      );
      canvas.drawCircle(petalTip, r * 0.14, microStroke);
    }

    // Vivienne wooden head sphere
    canvas.drawCircle(
      headCenter,
      r * 0.42,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(headCenter.dx - r * 0.12, headCenter.dy - r * 0.12),
          r * 0.54,
          const <Color>[
            Color(0xFFFAD7A0),
            Color(0xFFE3A17B),
            Color(0xFFA05A36),
          ],
          const <double>[0.0, 0.60, 1.0],
        ),
    );
    canvas.drawCircle(headCenter, r * 0.42, stroke);

    // Ski goggles on Vivienne's forehead
    final RRect goggles = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(headCenter.dx, headCenter.dy - r * 0.18),
        width: r * 0.64,
        height: r * 0.22,
      ),
      Radius.circular(r * 0.10),
    );
    canvas.drawRRect(goggles, Paint()..color = const Color(0xFF29B6F6));
    canvas.drawRRect(goggles, fineStroke);

    // 360° Orbital cyan arrow wrapping the front of the pedestal
    final Path orbitArc = Path()
      ..addArc(
        Rect.fromCenter(
          center: Offset(c.dx, c.dy + r * 0.46),
          width: r * 1.76,
          height: r * 0.56,
        ),
        0.15,
        math.pi - 0.30,
      );
    canvas.drawPath(
      orbitArc,
      Paint()
        ..color = const Color(0xFF29B6F6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.8, r * 0.13)
        ..strokeCap = StrokeCap.round,
    );

    // Layer 4: Crisp hard-edged white specular highlights
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(headCenter.dx - r * 0.14, headCenter.dy - r * 0.18),
        width: r * 0.20,
        height: r * 0.08,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  /// 8. Emblème Triangle Play Glisse dynamique
  void _paintPlayTriangle(
    Canvas canvas,
    Offset c,
    double r,
    Paint stroke,
    Paint fineStroke,
    Paint microStroke,
  ) {
    // Speed ice carving trails on the left
    for (int i = -1; i <= 1; i++) {
      final RRect speedBar = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(c.dx - r * 0.68, c.dy + i * r * 0.34),
          width: r * 0.38,
          height: r * 0.12,
        ),
        Radius.circular(r * 0.06),
      );
      canvas.drawRRect(speedBar, Paint()..color = const Color(0xFF80D8FF));
      canvas.drawRRect(speedBar, microStroke);
    }

    Path buildTriangle(Offset offset, double scale) {
      final double sr = r * scale;
      return Path()
        ..moveTo(offset.dx - sr * 0.42, offset.dy - sr * 0.72)
        ..lineTo(offset.dx + sr * 0.78, offset.dy)
        ..lineTo(offset.dx - sr * 0.42, offset.dy + sr * 0.72)
        ..close();
    }

    // Layer 1: Extruded 3D triangle shadow
    canvas.drawPath(
      buildTriangle(Offset(c.dx + r * 0.05, c.dy + r * 0.08), 1.0),
      Paint()..color = _kOutline.withValues(alpha: 0.42),
    );

    // Layer 2: Main 24K Gold Play Triangle
    final Path tri = buildTriangle(c, 1.0);
    canvas.drawPath(
      tri,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(c.dx - r * 0.5, c.dy - r * 0.7),
          Offset(c.dx + r * 0.7, c.dy + r * 0.7),
          const <Color>[
            Color(0xFFFFFDE7),
            Color(0xFFFFD700),
            Color(0xFFFF6F00),
          ],
          const <double>[0.0, 0.50, 1.0],
        ),
    );
    canvas.drawPath(tri, stroke);

    // Inner recessed golden bevel
    final Path innerTri = buildTriangle(Offset(c.dx + r * 0.02, c.dy), 0.66);
    canvas.drawPath(innerTri, Paint()..color = const Color(0xFFFFCA28));
    canvas.drawPath(innerTri, microStroke);

    // Layer 3: Fresh snow crest draped along upper bevel
    final Path snowCrest = Path()
      ..moveTo(c.dx - r * 0.42, c.dy - r * 0.72)
      ..lineTo(c.dx + r * 0.24, c.dy - r * 0.32)
      ..quadraticBezierTo(
        c.dx + r * 0.04,
        c.dy - r * 0.20,
        c.dx - r * 0.12,
        c.dy - r * 0.36,
      )
      ..quadraticBezierTo(
        c.dx - r * 0.28,
        c.dy - r * 0.26,
        c.dx - r * 0.42,
        c.dy - r * 0.44,
      )
      ..close();
    canvas.drawPath(snowCrest, Paint()..color = Colors.white);
    canvas.drawPath(snowCrest, fineStroke);

    // Layer 4: Crisp hard-edged white specular highlights
    final Path spec = Path()
      ..moveTo(c.dx - r * 0.32, c.dy - r * 0.56)
      ..lineTo(c.dx + r * 0.14, c.dy - r * 0.28)
      ..lineTo(c.dx + r * 0.08, c.dy - r * 0.20)
      ..lineTo(c.dx - r * 0.32, c.dy - r * 0.44)
      ..close();
    canvas.drawPath(
      spec,
      Paint()..color = Colors.white.withValues(alpha: 0.90),
    );
  }

  Path _buildFourPointStar(Offset center, double outerR, double innerR) {
    final Path path = Path();
    for (int i = 0; i < 8; i++) {
      final double a = -math.pi / 2 + i * (math.pi / 4);
      final double rad = i.isEven ? outerR : innerR;
      final Offset p = Offset(
        center.dx + math.cos(a) * rad,
        center.dy + math.sin(a) * rad,
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _SkiCartoonEmblemPainter oldDelegate) {
    return oldDelegate.kind != kind;
  }
}
