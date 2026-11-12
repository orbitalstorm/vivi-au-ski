import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Vector Cartoon Emblems & Badges for `VIVI AU SKI : Descente Royale 3D` (`v1.0.0`).
///
/// Rendered via a 4-layer Cartoon protocol:
/// 1. Ground drop shadow
/// 2. Multi-stop cel-shaded fills with thick `#2B1105` outlines
/// 3. Sub-assemblies & details
/// 4. Crisp hard-edged white specular highlights (`#FFFFFF`)
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

    final Paint stroke = Paint()
      ..color = _kOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.6, r * 0.14)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final Paint fineStroke = Paint()
      ..color = _kOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, r * 0.08)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + r * 0.90),
        width: r * 1.32,
        height: r * 0.24,
      ),
      Paint()..color = _kOutline.withValues(alpha: 0.28),
    );

    switch (kind) {
      case SkiCartoonEmblemKind.greenTrackBadge:
        _paintGreenTrackBadge(canvas, center, r, stroke, fineStroke);
      case SkiCartoonEmblemKind.blueTrackBadge:
        _paintBlueTrackBadge(canvas, center, r, stroke, fineStroke);
      case SkiCartoonEmblemKind.blackGoldTrackBadge:
        _paintBlackGoldBadge(canvas, center, r, stroke, fineStroke);
      case SkiCartoonEmblemKind.skiTrophyCup:
        _paintTrophyCup(canvas, center, r, stroke, fineStroke);
      case SkiCartoonEmblemKind.jumpTrickStar:
        _paintJumpTrickStar(canvas, center, r, stroke, fineStroke);
      case SkiCartoonEmblemKind.accelerometerTilt:
        _paintAccelerometerTilt(canvas, center, r, stroke, fineStroke);
      case SkiCartoonEmblemKind.turntableGallery:
        _paintTurntableGallery(canvas, center, r, stroke, fineStroke);
      case SkiCartoonEmblemKind.playSkiTriangle:
        _paintPlayTriangle(canvas, center, r, stroke);
    }
  }

  void _paintGreenTrackBadge(
    Canvas canvas,
    Offset c,
    double r,
    Paint stroke,
    Paint fineStroke,
  ) {
    final Path shield = Path()
      ..moveTo(c.dx, c.dy - r * 0.92)
      ..lineTo(c.dx + r * 0.80, c.dy - r * 0.56)
      ..lineTo(c.dx + r * 0.68, c.dy + r * 0.34)
      ..quadraticBezierTo(c.dx, c.dy + r * 0.92, c.dx, c.dy + r * 0.92)
      ..quadraticBezierTo(
        c.dx,
        c.dy + r * 0.92,
        c.dx - r * 0.68,
        c.dy + r * 0.34,
      )
      ..lineTo(c.dx - r * 0.80, c.dy - r * 0.56)
      ..close();

    canvas.drawPath(
      shield,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(c.dx, c.dy - r),
          Offset(c.dx, c.dy + r),
          const <Color>[Color(0xFF69F0AE), Color(0xFF00E676), Color(0xFF00964B)],
          const <double>[0.0, 0.55, 1.0],
        ),
    );
    canvas.drawPath(shield, stroke);

    final Offset sunCenter = Offset(c.dx + r * 0.34, c.dy - r * 0.34);
    canvas.drawCircle(
      sunCenter,
      r * 0.22,
      Paint()..color = const Color(0xFFFFD700),
    );
    canvas.drawCircle(sunCenter, r * 0.22, fineStroke);

    final Path tree = Path()
      ..moveTo(c.dx - r * 0.06, c.dy - r * 0.42)
      ..lineTo(c.dx - r * 0.48, c.dy + r * 0.26)
      ..lineTo(c.dx + r * 0.36, c.dy + r * 0.26)
      ..close();
    canvas.drawPath(tree, Paint()..color = const Color(0xFF1B5E20));
    canvas.drawPath(tree, fineStroke);

    final Path snowCap = Path()
      ..moveTo(c.dx - r * 0.06, c.dy - r * 0.42)
      ..lineTo(c.dx - r * 0.26, c.dy - r * 0.08)
      ..quadraticBezierTo(
        c.dx - r * 0.06,
        c.dy + r * 0.02,
        c.dx + r * 0.14,
        c.dy - r * 0.08,
      )
      ..close();
    canvas.drawPath(snowCap, Paint()..color = Colors.white);
  }

  void _paintBlueTrackBadge(
    Canvas canvas,
    Offset c,
    double r,
    Paint stroke,
    Paint fineStroke,
  ) {
    final Rect circleRect = Rect.fromCircle(center: c, radius: r * 0.88);
    canvas.drawOval(
      circleRect,
      Paint()
        ..shader = ui.Gradient.linear(
          circleRect.topCenter,
          circleRect.bottomCenter,
          const <Color>[Color(0xFF80D8FF), Color(0xFF29B6F6), Color(0xFF0277BD)],
          const <double>[0.0, 0.55, 1.0],
        ),
    );
    canvas.drawOval(circleRect, stroke);

    final Path peaks = Path()
      ..moveTo(c.dx - r * 0.62, c.dy + r * 0.36)
      ..lineTo(c.dx - r * 0.16, c.dy - r * 0.42)
      ..lineTo(c.dx + r * 0.14, c.dy + r * 0.08)
      ..lineTo(c.dx + r * 0.38, c.dy - r * 0.26)
      ..lineTo(c.dx + r * 0.66, c.dy + r * 0.36)
      ..close();
    canvas.drawPath(peaks, Paint()..color = const Color(0xFFE1F5FE));
    canvas.drawPath(peaks, fineStroke);

    for (final double angle in <double>[-0.55, 0.55]) {
      canvas.save();
      canvas.translate(c.dx, c.dy + r * 0.08);
      canvas.rotate(angle);
      final RRect ski = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: r * 1.15,
          height: r * 0.16,
        ),
        Radius.circular(r * 0.08),
      );
      canvas.drawRRect(ski, Paint()..color = const Color(0xFFFFD700));
      canvas.drawRRect(ski, fineStroke);
      canvas.restore();
    }
  }

  void _paintBlackGoldBadge(
    Canvas canvas,
    Offset c,
    double r,
    Paint stroke,
    Paint fineStroke,
  ) {
    final Path diamond = Path()
      ..moveTo(c.dx, c.dy - r * 0.94)
      ..lineTo(c.dx + r * 0.88, c.dy)
      ..lineTo(c.dx, c.dy + r * 0.94)
      ..lineTo(c.dx - r * 0.88, c.dy)
      ..close();
    canvas.drawPath(
      diamond,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(c.dx - r, c.dy - r),
          Offset(c.dx + r, c.dy + r),
          const <Color>[Color(0xFF37474F), Color(0xFF141E28), Color(0xFF070B10)],
          const <double>[0.0, 0.55, 1.0],
        ),
    );
    canvas.drawPath(diamond, stroke);

    final Path crown = Path()
      ..moveTo(c.dx - r * 0.42, c.dy + r * 0.24)
      ..lineTo(c.dx - r * 0.50, c.dy - r * 0.24)
      ..lineTo(c.dx - r * 0.18, c.dy - r * 0.02)
      ..lineTo(c.dx, c.dy - r * 0.38)
      ..lineTo(c.dx + r * 0.18, c.dy - r * 0.02)
      ..lineTo(c.dx + r * 0.50, c.dy - r * 0.24)
      ..lineTo(c.dx + r * 0.42, c.dy + r * 0.24)
      ..close();
    canvas.drawPath(crown, Paint()..color = const Color(0xFFFFD700));
    canvas.drawPath(crown, fineStroke);
  }

  void _paintTrophyCup(
    Canvas canvas,
    Offset c,
    double r,
    Paint stroke,
    Paint fineStroke,
  ) {
    final Path cup = Path()
      ..moveTo(c.dx - r * 0.56, c.dy - r * 0.72)
      ..lineTo(c.dx + r * 0.56, c.dy - r * 0.72)
      ..lineTo(c.dx + r * 0.42, c.dy + r * 0.08)
      ..quadraticBezierTo(c.dx, c.dy + r * 0.44, c.dx - r * 0.42, c.dy + r * 0.08)
      ..close();
    canvas.drawPath(
      cup,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(c.dx - r * 0.5, c.dy - r * 0.7),
          Offset(c.dx + r * 0.5, c.dy + r * 0.4),
          const <Color>[Color(0xFFFFF9C4), Color(0xFFFFD700), Color(0xFFC77800)],
          const <double>[0.0, 0.5, 1.0],
        ),
    );
    canvas.drawPath(cup, stroke);

    final RRect stem = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(c.dx, c.dy + r * 0.44),
        width: r * 0.26,
        height: r * 0.34,
      ),
      Radius.circular(r * 0.06),
    );
    canvas.drawRRect(stem, Paint()..color = const Color(0xFFFFB300));
    canvas.drawRRect(stem, fineStroke);

    final RRect base = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(c.dx, c.dy + r * 0.72),
        width: r * 0.86,
        height: r * 0.24,
      ),
      Radius.circular(r * 0.08),
    );
    canvas.drawRRect(base, Paint()..color = const Color(0xFF8B1E24));
    canvas.drawRRect(base, stroke);
  }

  void _paintJumpTrickStar(
    Canvas canvas,
    Offset c,
    double r,
    Paint stroke,
    Paint fineStroke,
  ) {
    final Path star = Path();
    for (int i = 0; i < 10; i++) {
      final double angle = -math.pi / 2 + i * (math.pi / 5);
      final double rad = i.isEven ? r * 0.86 : r * 0.38;
      final Offset p = Offset(
        c.dx + math.cos(angle) * rad,
        c.dy + math.sin(angle) * rad,
      );
      if (i == 0) {
        star.moveTo(p.dx, p.dy);
      } else {
        star.lineTo(p.dx, p.dy);
      }
    }
    star.close();
    canvas.drawPath(
      star,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(c.dx, c.dy - r),
          Offset(c.dx, c.dy + r),
          const <Color>[Color(0xFFFFFDE7), Color(0xFFFFD700), Color(0xFFFF8F00)],
          const <double>[0.0, 0.55, 1.0],
        ),
    );
    canvas.drawPath(star, stroke);
    canvas.drawCircle(
      Offset(c.dx - r * 0.14, c.dy - r * 0.22),
      r * 0.12,
      Paint()..color = Colors.white.withValues(alpha: 0.8),
    );
  }

  void _paintAccelerometerTilt(
    Canvas canvas,
    Offset c,
    double r,
    Paint stroke,
    Paint fineStroke,
  ) {
    canvas.save();
    canvas.translate(c.dx, c.dy + r * 0.06);
    canvas.rotate(-0.28);
    final RRect phone = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: r * 0.82, height: r * 1.32),
      Radius.circular(r * 0.18),
    );
    canvas.drawRRect(phone, Paint()..color = const Color(0xFF37474F));
    canvas.drawRRect(phone, stroke);

    final RRect screen = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: r * 0.62, height: r * 0.96),
      Radius.circular(r * 0.10),
    );
    canvas.drawRRect(screen, Paint()..color = const Color(0xFF4FC3F7));
    canvas.drawRRect(screen, fineStroke);
    canvas.restore();
  }

  void _paintTurntableGallery(
    Canvas canvas,
    Offset c,
    double r,
    Paint stroke,
    Paint fineStroke,
  ) {
    final Rect baseOval = Rect.fromCenter(
      center: Offset(c.dx, c.dy + r * 0.44),
      width: r * 1.56,
      height: r * 0.54,
    );
    canvas.drawOval(baseOval, Paint()..color = const Color(0xFFFFD700));
    canvas.drawOval(baseOval, stroke);

    canvas.drawCircle(
      Offset(c.dx, c.dy - r * 0.18),
      r * 0.48,
      Paint()..color = const Color(0xFFE3A17B),
    );
    canvas.drawCircle(Offset(c.dx, c.dy - r * 0.18), r * 0.48, fineStroke);
  }

  void _paintPlayTriangle(
    Canvas canvas,
    Offset c,
    double r,
    Paint stroke,
  ) {
    final Path tri = Path()
      ..moveTo(c.dx - r * 0.46, c.dy - r * 0.68)
      ..lineTo(c.dx + r * 0.72, c.dy)
      ..lineTo(c.dx - r * 0.46, c.dy + r * 0.68)
      ..close();
    canvas.drawPath(
      tri,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(c.dx - r * 0.5, c.dy - r * 0.7),
          Offset(c.dx + r * 0.7, c.dy + r * 0.7),
          const <Color>[Color(0xFFFFFDE7), Color(0xFFFFD700), Color(0xFFFF8F00)],
          const <double>[0.0, 0.55, 1.0],
        ),
    );
    canvas.drawPath(tri, stroke);
  }

  @override
  bool shouldRepaint(covariant _SkiCartoonEmblemPainter oldDelegate) {
    return oldDelegate.kind != kind;
  }
}
