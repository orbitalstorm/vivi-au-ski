import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'engine/ski_game_engine.dart';
import 'models/ski_models.dart';
import 'painters/ski_3d_painter.dart';
import 'painters/vivi_ski_cartoon_assets.dart';
import 'painters/vivienne_3d_volumetric_rig.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF2B1105),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ViviAuSkiApp());
}

void _triggerHaptic(SkiHapticEvent event) {
  switch (event) {
    case SkiHapticEvent.carveEdge:
    case SkiHapticEvent.blossomPickup:
      HapticFeedback.selectionClick();
    case SkiHapticEvent.mogulBump:
    case SkiHapticEvent.slalomGate:
      HapticFeedback.lightImpact();
    case SkiHapticEvent.rampLaunch:
    case SkiHapticEvent.landingImpact:
      HapticFeedback.mediumImpact();
    case SkiHapticEvent.obstacleBounce:
    case SkiHapticEvent.trackFinished:
      HapticFeedback.heavyImpact();
  }
}

/// Tactile 3D Cartoon Button implementing `mobile-game-ui` v1.2.0 (Mode B Flutter):
/// - Immediate Squash & Stretch (`AnimatedScale` 0.92 on pointer down)
/// - Physical 3D bottom lip (`lipDepth: 6.0`) that compresses to `0.0` on press
/// - Crisp top specular highlight pill (`#FFFFFF`) & thick `#2B1105` outline
/// - Guaranteed minimum 48x48dp touch target (`ConstrainedBox`)
/// - Native iOS/Android haptic impact (`HapticFeedback.lightImpact`)
class JuicySki3DButton extends StatefulWidget {
  const JuicySki3DButton({
    super.key,
    required this.onTap,
    required this.child,
    this.backgroundColor = const Color(0xFFFFD700),
    this.lipColor = const Color(0xFFB26A00),
    this.borderColor = const Color(0xFF2B1105),
    this.borderRadius = 20.0,
    this.lipDepth = 6.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    this.minWidth = 48.0,
    this.minHeight = 48.0,
  });

  final VoidCallback onTap;
  final Widget child;
  final Color backgroundColor;
  final Color lipColor;
  final Color borderColor;
  final double borderRadius;
  final double lipDepth;
  final EdgeInsetsGeometry padding;
  final double minWidth;
  final double minHeight;

  @override
  State<JuicySki3DButton> createState() => _JuicySki3DButtonState();
}

class _JuicySki3DButtonState extends State<JuicySki3DButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final double activeLip = _pressed ? 0.0 : widget.lipDepth;
    final double dy = _pressed ? widget.lipDepth : 0.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: widget.minWidth,
          minHeight: widget.minHeight,
        ),
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1.0,
          duration: Duration(milliseconds: _pressed ? 70 : 180),
          curve: _pressed ? Curves.easeOutCubic : Curves.elasticOut,
          child: Transform.translate(
            offset: Offset(0, dy),
            child: Container(
              decoration: BoxDecoration(
                color: widget.backgroundColor,
                borderRadius: BorderRadius.circular(widget.borderRadius),
                border: Border.all(color: widget.borderColor, width: 2.8),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: widget.lipColor,
                    blurRadius: 0,
                    offset: Offset(0, activeLip),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  // Crisp cartoon specular highlight along the top edge
                  Positioned(
                    top: 3,
                    left: 12,
                    right: 12,
                    child: IgnorePointer(
                      child: Container(
                        height: 3.5,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: widget.padding,
                    child: widget.child,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Decorative Cartoon Snow-Capped Roof with dripping snow scallops and specular shine.
class _CartoonSnowCapDecoration extends StatelessWidget {
  const _CartoonSnowCapDecoration({
    this.height = 16.0,
  });

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: CustomPaint(
        painter: const _CartoonSnowCapPainter(),
      ),
    );
  }
}

class _CartoonSnowCapPainter extends CustomPainter {
  const _CartoonSnowCapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    if (w <= 0 || h <= 0) return;

    final Path snowPath = Path()
      ..moveTo(2, h * 0.35)
      ..quadraticBezierTo(w * 0.25, 0, w * 0.5, h * 0.12)
      ..quadraticBezierTo(w * 0.75, 0, w - 2, h * 0.35)
      ..lineTo(w - 2, h * 0.62)
      ..quadraticBezierTo(w * 0.86, h * 1.0, w * 0.72, h * 0.58)
      ..quadraticBezierTo(w * 0.58, h * 1.0, w * 0.44, h * 0.60)
      ..quadraticBezierTo(w * 0.28, h * 1.0, w * 0.14, h * 0.58)
      ..quadraticBezierTo(w * 0.05, h * 0.92, 2, h * 0.62)
      ..close();

    canvas.drawPath(
      snowPath,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, h),
          const <Color>[Color(0xFFFFFFFF), Color(0xFFE1F5FE)],
        ),
    );

    canvas.drawPath(
      snowPath,
      Paint()
        ..color = const Color(0xFF2B1105)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeJoin = StrokeJoin.round,
    );

    // Specular white highlight
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.20, h * 0.18, w * 0.60, h * 0.20),
        const Radius.circular(3),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(covariant _CartoonSnowCapPainter oldDelegate) => false;
}

class ViviAuSkiApp extends StatelessWidget {
  const ViviAuSkiApp({
    super.key,
    this.engine,
    this.initialRearPoseSprites,
    this.initialFrontPoseSprites,
    this.initialTurntableSprites,
    this.initialPoseSprites,
    this.initialLvNeoBannerImage,
    this.initialEditionHeroSprites,
    this.autoStartTicker = true,
    this.screenshotBoundaryKey,
  });

  final SkiGameEngine? engine;
  final Map<VivienneSkiEdition, List<ui.Image?>>? initialRearPoseSprites;
  final Map<VivienneSkiEdition, List<ui.Image?>>? initialFrontPoseSprites;
  final List<ui.Image?>? initialTurntableSprites;
  final Map<VivienneBlenderPose, ui.Image>? initialPoseSprites;
  final ui.Image? initialLvNeoBannerImage;
  final Map<VivienneSkiEdition, ui.Image>? initialEditionHeroSprites;
  final bool autoStartTicker;
  final GlobalKey? screenshotBoundaryKey;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vivi au Ski 3D',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFF1E88E5),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFFFD700),
          secondary: Color(0xFF29B6F6),
          surface: Color(0xFFFFF8E7),
        ),
        useMaterial3: true,
      ),
      home: ViviAuSkiHomeScreen(
        engine: engine,
        initialRearPoseSprites: initialRearPoseSprites,
        initialFrontPoseSprites: initialFrontPoseSprites,
        initialTurntableSprites: initialTurntableSprites,
        initialPoseSprites: initialPoseSprites,
        initialLvNeoBannerImage: initialLvNeoBannerImage,
        initialEditionHeroSprites: initialEditionHeroSprites,
        autoStartTicker: autoStartTicker,
        screenshotBoundaryKey: screenshotBoundaryKey,
      ),
    );
  }
}

class ViviAuSkiHomeScreen extends StatefulWidget {
  const ViviAuSkiHomeScreen({
    super.key,
    this.engine,
    this.initialRearPoseSprites,
    this.initialFrontPoseSprites,
    this.initialTurntableSprites,
    this.initialPoseSprites,
    this.initialLvNeoBannerImage,
    this.initialEditionHeroSprites,
    this.autoStartTicker = true,
    this.screenshotBoundaryKey,
  });

  final SkiGameEngine? engine;
  final Map<VivienneSkiEdition, List<ui.Image?>>? initialRearPoseSprites;
  final Map<VivienneSkiEdition, List<ui.Image?>>? initialFrontPoseSprites;
  final List<ui.Image?>? initialTurntableSprites;
  final Map<VivienneBlenderPose, ui.Image>? initialPoseSprites;
  final ui.Image? initialLvNeoBannerImage;
  final Map<VivienneSkiEdition, ui.Image>? initialEditionHeroSprites;
  final bool autoStartTicker;
  final GlobalKey? screenshotBoundaryKey;

  @override
  State<ViviAuSkiHomeScreen> createState() => _ViviAuSkiHomeScreenState();
}

class _ViviAuSkiHomeScreenState extends State<ViviAuSkiHomeScreen>
    with SingleTickerProviderStateMixin {
  static const EventChannel _accelChannel = EventChannel(
    'cloud.orbital8.vivi_au_ski/accelerometer',
  );
  static const MethodChannel _deviceChannel = MethodChannel(
    'cloud.orbital8.vivi_au_ski/device',
  );

  late final SkiGameEngine _engine;
  late final bool _ownsEngine;
  late final FocusNode _keyboardFocusNode;

  Ticker? _ticker;
  Duration _lastTick = Duration.zero;
  StreamSubscription<Object?>? _accelSubscription;

  final Map<VivienneSkiEdition, List<ui.Image?>> _rearPoseSprites =
      <VivienneSkiEdition, List<ui.Image?>>{};
  final Map<VivienneSkiEdition, List<ui.Image?>> _frontPoseSprites =
      <VivienneSkiEdition, List<ui.Image?>>{};
  final List<ui.Image?> _turntableSprites = List<ui.Image?>.filled(
    VivienneTurntableSpec.frameCount,
    null,
  );
  final Map<VivienneBlenderPose, ui.Image> _poseSprites =
      <VivienneBlenderPose, ui.Image>{};
  ui.Image? _lvNeoBannerImage;
  final Map<VivienneSkiEdition, ui.Image> _editionHeroSprites =
      <VivienneSkiEdition, ui.Image>{};
  double _pauseInspectionYawDegrees = 58.0;

  @override
  void initState() {
    super.initState();
    _ownsEngine = widget.engine == null;
    _engine = widget.engine ??
        SkiGameEngine(
          onHapticEvent: _triggerHaptic,
        );
    _keyboardFocusNode = FocusNode();

    for (final VivienneSkiEdition ed in VivienneSkiEdition.values) {
      _rearPoseSprites[ed] = List<ui.Image?>.filled(5, null);
      _frontPoseSprites[ed] = List<ui.Image?>.filled(5, null);
    }

    if (widget.initialRearPoseSprites != null) {
      for (final MapEntry<VivienneSkiEdition, List<ui.Image?>> entry
          in widget.initialRearPoseSprites!.entries) {
        _rearPoseSprites[entry.key] = List<ui.Image?>.from(entry.value);
      }
    }
    if (widget.initialFrontPoseSprites != null) {
      for (final MapEntry<VivienneSkiEdition, List<ui.Image?>> entry
          in widget.initialFrontPoseSprites!.entries) {
        _frontPoseSprites[entry.key] = List<ui.Image?>.from(entry.value);
      }
    }
    if (widget.initialRearPoseSprites == null ||
        widget.initialFrontPoseSprites == null) {
      _loadEditionPoseSprites(
        loadRear: widget.initialRearPoseSprites == null,
        loadFront: widget.initialFrontPoseSprites == null,
      );
    }

    if (widget.initialTurntableSprites != null) {
      final int count = math.min(
        _turntableSprites.length,
        widget.initialTurntableSprites!.length,
      );
      for (int i = 0; i < count; i++) {
        _turntableSprites[i] = widget.initialTurntableSprites![i];
      }
    } else {
      _loadTurntableSprites();
    }

    if (widget.initialPoseSprites != null) {
      _poseSprites.addAll(widget.initialPoseSprites!);
    } else {
      _loadPoseSprites();
    }

    if (widget.initialLvNeoBannerImage != null) {
      _lvNeoBannerImage = widget.initialLvNeoBannerImage;
    } else {
      _loadLvNeoBannerImage();
    }

    if (widget.initialEditionHeroSprites != null) {
      _editionHeroSprites.addAll(widget.initialEditionHeroSprites!);
    } else {
      _loadEditionHeroSprites();
    }

    if (widget.autoStartTicker) {
      _subscribeHardwareAccelerometer();
      _ticker = createTicker(_onTick)..start();
    }
  }

  Future<void> _loadEditionPoseSprites({
    required bool loadRear,
    required bool loadFront,
  }) async {
    for (final VivienneSkiEdition ed in VivienneSkiEdition.values) {
      if (loadRear) {
        final List<String> paths = ed.rearPoseAssetPaths;
        for (int i = 0; i < paths.length; i++) {
          try {
            final ByteData data = await rootBundle.load(paths[i]);
            final ui.Codec codec = await ui.instantiateImageCodec(
              data.buffer.asUint8List(),
            );
            final ui.FrameInfo frame = await codec.getNextFrame();
            if (!mounted) return;
            setState(() {
              _rearPoseSprites[ed]![i] = frame.image;
            });
          } catch (_) {}
        }
      }
      if (loadFront) {
        final List<String> paths = ed.frontPoseAssetPaths;
        for (int i = 0; i < paths.length; i++) {
          try {
            final ByteData data = await rootBundle.load(paths[i]);
            final ui.Codec codec = await ui.instantiateImageCodec(
              data.buffer.asUint8List(),
            );
            final ui.FrameInfo frame = await codec.getNextFrame();
            if (!mounted) return;
            setState(() {
              _frontPoseSprites[ed]![i] = frame.image;
            });
          } catch (_) {}
        }
      }
    }
  }

  Future<void> _loadTurntableSprites() async {
    for (int i = 0; i < VivienneTurntableSpec.frameCount; i++) {
      try {
        final ByteData data = await rootBundle.load(
          VivienneTurntableSpec.assetPathForIndex(i),
        );
        final ui.Codec codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(),
        );
        final ui.FrameInfo frame = await codec.getNextFrame();
        if (!mounted) return;
        setState(() {
          _turntableSprites[i] = frame.image;
        });
      } catch (_) {
        // Procedural 3D rig fallback handles missing sprite gracefully.
      }
    }
  }

  Future<void> _loadPoseSprites() async {
    for (final VivienneBlenderPose pose in VivienneBlenderPose.values) {
      try {
        final ByteData data = await rootBundle.load(pose.assetPath);
        final ui.Codec codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(),
        );
        final ui.FrameInfo frame = await codec.getNextFrame();
        if (!mounted) return;
        setState(() {
          _poseSprites[pose] = frame.image;
        });
      } catch (_) {}
    }
  }

  Future<void> _loadLvNeoBannerImage() async {
    try {
      final ByteData data =
          await rootBundle.load('assets/sprites/lv_neo_banner.png');
      final ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
      );
      final ui.FrameInfo frame = await codec.getNextFrame();
      if (!mounted) return;
      setState(() {
        _lvNeoBannerImage = frame.image;
      });
    } catch (_) {
      // Vector LV_NEO fallback in Ski3DPainter handles missing banner sprite.
    }
  }

  Future<void> _loadEditionHeroSprites() async {
    for (final VivienneSkiEdition ed in VivienneSkiEdition.values) {
      try {
        final ByteData data = await rootBundle.load(ed.heroAssetPath);
        final ui.Codec codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(),
        );
        final ui.FrameInfo frame = await codec.getNextFrame();
        if (!mounted) return;
        setState(() {
          _editionHeroSprites[ed] = frame.image;
        });
      } catch (_) {}
    }
  }

  Future<void> _subscribeHardwareAccelerometer() async {
    try {
      await _deviceChannel.invokeMethod<bool>('hasAccelerometer');
    } catch (_) {}

    try {
      _accelSubscription = _accelChannel.receiveBroadcastStream().listen(
        (Object? event) {
          if (event is Map<Object?, Object?>) {
            final num? x = event['x'] as num?;
            final num? y = event['y'] as num?;
            final num? z = event['z'] as num?;
            if (x != null && y != null && z != null) {
              _engine.updateHardwareSensor(
                x.toDouble(),
                y.toDouble(),
                z.toDouble(),
              );
            }
          } else if (event is List<Object?> && event.length >= 3) {
            final num? x = event[0] as num?;
            final num? y = event[1] as num?;
            final num? z = event[2] as num?;
            if (x != null && y != null && z != null) {
              _engine.updateHardwareSensor(
                x.toDouble(),
                y.toDouble(),
                z.toDouble(),
              );
            }
          }
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  void _onTick(Duration elapsed) {
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }
    final double dt =
        (elapsed - _lastTick).inMicroseconds / Duration.microsecondsPerSecond;
    _lastTick = elapsed;
    _engine.update(dt);
  }

  KeyEventResult _handleKeyEvent(FocusNode _, KeyEvent event) {
    if (event is KeyDownEvent) {
      if ((event.logicalKey == LogicalKeyboardKey.escape ||
              event.logicalKey == LogicalKeyboardKey.keyP) &&
          !_engine.isInMenu &&
          !_engine.isTrackFinished) {
        _engine.togglePause();
        return KeyEventResult.handled;
      }
    }
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
          event.logicalKey == LogicalKeyboardKey.keyA) {
        _engine.setManualTilt(-0.85);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
          event.logicalKey == LogicalKeyboardKey.keyD) {
        _engine.setManualTilt(0.85);
        return KeyEventResult.handled;
      }
    } else if (event is KeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
          event.logicalKey == LogicalKeyboardKey.arrowRight ||
          event.logicalKey == LogicalKeyboardKey.keyA ||
          event.logicalKey == LogicalKeyboardKey.keyD) {
        _engine.clearManualTilt();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _accelSubscription?.cancel();
    _keyboardFocusNode.dispose();
    if (_ownsEngine) {
      _engine.dispose();
    }
    super.dispose();
  }

  SkiCartoonEmblemKind _emblemForTrack(SkiTrackId track) {
    switch (track) {
      case SkiTrackId.greenBlossomValley:
        return SkiCartoonEmblemKind.greenTrackBadge;
      case SkiTrackId.blueAsnieresForest:
        return SkiCartoonEmblemKind.blueTrackBadge;
      case SkiTrackId.blackVendomePeaks:
        return SkiCartoonEmblemKind.blackGoldTrackBadge;
    }
  }

  Color _speedDynamicColor(double speedKmh, SkiTrackId track) {
    final double ratio =
        (speedKmh / track.maxSpeedKmh).clamp(0.0, 1.35);
    if (ratio >= 0.96) {
      return const Color(0xFFD50000); // High-velocity / Turbo Red-Crimson
    } else if (ratio >= 0.78) {
      return const Color(0xFFE65100); // Carving Amber-Orange
    } else if (ratio >= 0.58) {
      return const Color(0xFF008E46); // Crisp Alpine Emerald
    }
    return const Color(0xFF0277BD); // Glacier Azure
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = Focus(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // 60-120 FPS 3D Rear Perspective Ski Renderer isolated in its own RepaintBoundary
            RepaintBoundary(
              child: CustomPaint(
                painter: Ski3DPainter(
                  engine: _engine,
                  rearPoseSprites: _rearPoseSprites,
                  frontPoseSprites: _frontPoseSprites,
                  editionHeroSprites: _editionHeroSprites,
                  turntableSprites: _turntableSprites,
                  poseSprites: _poseSprites,
                  lvNeoBannerImage: _lvNeoBannerImage,
                ),
                size: Size.infinite,
              ),
            ),

            // Cartoon UI & HUD Layer
            RepaintBoundary(
              child: ListenableBuilder(
                listenable: _engine,
                builder: (BuildContext context, Widget? _) {
                  return SafeArea(
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        if (!_engine.isInMenu) _buildActiveSkiHud(),
                        if (_engine.isInMenu &&
                            !_engine.isHighscoresOpen &&
                            !_engine.isTurntableGalleryOpen)
                          _buildMainMenuOverlay(),
                        if (_engine.isHighscoresOpen) _buildHighscoresOverlay(),
                        if (_engine.isTurntableGalleryOpen)
                          _buildTurntableGalleryOverlay(),
                        if (!_engine.isInMenu &&
                            _engine.isPaused &&
                            !_engine.isTrackFinished)
                          _buildPauseOverlay(),
                        if (_engine.isTrackFinished &&
                            !_engine.isHighscoresOpen)
                          _buildTrackFinishedOverlay(),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.screenshotBoundaryKey != null) {
      return RepaintBoundary(
        key: widget.screenshotBoundaryKey,
        child: content,
      );
    }
    return content;
  }

  // ---------------------------------------------------------------------------
  // Cartoon Main Menu (`main_menu_overlay`)
  // ---------------------------------------------------------------------------

  Widget _buildMainMenuOverlay() {
    final VivienneSkiEdition activeEdition = _engine.selectedEdition;
    final double menuPreviewYaw =
        34.0 + math.sin(_engine.ambientTime * 1.15) * 24.0;

    return Container(
      key: const Key('main_menu_overlay'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
            decoration: BoxDecoration(
              color: const Color(0xF5FFF8E7),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFF2B1105), width: 3.2),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0xFF4A2511),
                  blurRadius: 0,
                  offset: Offset(0, 7),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const _CartoonSnowCapDecoration(height: 13),
                const SizedBox(height: 4),

                // Header Banner with Specular Shine
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Color(0xFF4FC3F7),
                        Color(0xFF0288D1),
                        Color(0xFF01579B),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: const Color(0xFF2B1105), width: 2.6),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0xFF003c6c),
                        blurRadius: 0,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Column(
                    children: <Widget>[
                      Text(
                        'VIVI AU SKI 3D',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'DESCENTE ROYALE v1.3 • VRAI RENDU 3D VOLUMÉTRIQUE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9.8,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFFF59D),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 7),

                // Live 60 FPS Real-Time 3D Volumetric Preview + 3 Official BLENDER_LAB Models Selector
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: <Color>[Color(0xFFE1F5FE), Color(0xFFFFF9C4)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFF2B1105),
                      width: 2.2,
                    ),
                  ),
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              gradient: const RadialGradient(
                                colors: <Color>[
                                  Color(0xFFFFFFFF),
                                  Color(0xFFB3E5FC),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFF2B1105),
                                width: 2.2,
                              ),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: activeEdition.trimEdgeColor,
                                  blurRadius: 0,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Vivienne3DViewport(
                                key: const Key('menu_vivienne_3d_viewport'),
                                edition: activeEdition,
                                yawDegrees: menuPreviewYaw,
                                mode: VivienneMotionMode.showcase360,
                                externalTimeSeconds: _engine.ambientTime,
                                includeSkisAndPoles: false,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  activeEdition.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.6,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF2B1105),
                                  ),
                                ),
                                Text(
                                  activeEdition.subtitle,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 9.8,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1638E8),
                                  ),
                                ),
                                Text(
                                  activeEdition.perkLabel,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 9.8,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF8B1E24),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: VivienneSkiEdition.values
                            .map((VivienneSkiEdition ed) {
                          final bool selected = _engine.selectedEdition == ed;
                          final String shortLabel = switch (ed) {
                            VivienneSkiEdition.speedyV03 => 'Speedy v03',
                            VivienneSkiEdition.wonderland => 'Wonderland',
                            VivienneSkiEdition.giantDenim => 'Giant Denim',
                          };
                          return Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 3),
                              child: GestureDetector(
                                key: Key('select_edition_${ed.id}'),
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  _engine.selectEdition(ed);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 140),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? const Color(0xFFFFD700)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFF2B1105),
                                      width: selected ? 2.2 : 1.5,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      SizedBox(
                                        width: 30,
                                        height: 30,
                                        child: Vivienne3DViewport(
                                          edition: ed,
                                          yawDegrees: 32.0,
                                          mode: VivienneMotionMode.showcase360,
                                          externalTimeSeconds:
                                              _engine.ambientTime,
                                          animate: false,
                                          includeSkisAndPoles: false,
                                          drawStudioShadow: false,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        shortLabel,
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 9.6,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF2B1105),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 7),

                // 3 Ski Tracks Selection Cards
                for (final SkiTrackId track in SkiTrackId.values) ...<Widget>[
                  _buildTrackCard(track),
                  const SizedBox(height: 7),
                ],

                const SizedBox(height: 3),

                // Primary Play Button: DÉVALER LA PISTE !
                SizedBox(
                  width: double.infinity,
                  child: JuicySki3DButton(
                    key: const Key('start_ski_run_button'),
                    backgroundColor: const Color(0xFF00E676),
                    lipColor: const Color(0xFF008E46),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                    onTap: () => _engine.startRun(),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        SkiCartoonEmblemBadge(
                          kind: SkiCartoonEmblemKind.playSkiTriangle,
                          size: 26,
                        ),
                        SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'DÉVALER LA PISTE !',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 17.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF2B1105),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 9),

                // Secondary Action Row: TABLEAU DES SCORES & GALERIE VIVIENNE 3D
                Row(
                  children: <Widget>[
                    Expanded(
                      child: JuicySki3DButton(
                        key: const Key('open_highscores_button'),
                        backgroundColor: const Color(0xFFFFD700),
                        lipColor: const Color(0xFFB26A00),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 9,
                        ),
                        onTap: () => _engine.openHighscores(),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            SkiCartoonEmblemBadge(
                              kind: SkiCartoonEmblemKind.skiTrophyCup,
                              size: 22,
                            ),
                            SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                'TABLEAU SCORES',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF2B1105),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: JuicySki3DButton(
                        key: const Key('open_turntable_gallery_button'),
                        backgroundColor: const Color(0xFF80D8FF),
                        lipColor: const Color(0xFF0277BD),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 9,
                        ),
                        onTap: () => _engine.openTurntableGallery(),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            SkiCartoonEmblemBadge(
                              kind: SkiCartoonEmblemKind.turntableGallery,
                              size: 22,
                            ),
                            SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                'GALERIE 3D',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF2B1105),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrackCard(SkiTrackId track) {
    final bool isSelected = _engine.selectedTrack == track;
    final int best = _engine.bestScoreForTrack(track);

    return GestureDetector(
      key: Key(track.selectKeyName),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        _engine.selectTrack(track);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF3C4) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFF2B1105),
            width: isSelected ? 3.0 : 2.0,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: isSelected ? track.badgeLipColor : const Color(0x26000000),
              blurRadius: 0,
              offset: Offset(0, isSelected ? 4 : 2),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            SkiCartoonEmblemBadge(kind: _emblemForTrack(track), size: 36),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          track.difficultyLabel,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9.8,
                            fontWeight: FontWeight.w900,
                            color: track.badgeLipColor,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2B1105),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$best pts',
                          style: const TextStyle(
                            fontSize: 10.0,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFFD700),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    track.title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.2,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2B1105),
                    ),
                  ),
                  Text(
                    track.summaryMetrics,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9.4,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF5D4037),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Real-Time 3D Ski HUD (60-120 FPS RepaintBoundary-isolated)
  // ---------------------------------------------------------------------------

  Widget _buildActiveSkiHud() {
    final SkiTrackId track = _engine.selectedTrack;
    final Color speedColor = _speedDynamicColor(_engine.speedKmh, track);
    final bool isAirborne =
        _engine.animState == VivienneSkiAnimState.airborneCelebration ||
            _engine.animState == VivienneSkiAnimState.rampLaunchStretch;

    return Padding(
      // Maintain >=16dp edge margin for system gesture safety on Android/iOS
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          // Top HUD Bar: Speed, Progress, Score & Menu
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xF0FFF8E7),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: const Color(0xFF2B1105), width: 2.6),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x552B1105),
                      blurRadius: 0,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: <Widget>[
                    // Interpolated Speed Counter (km/h) with Dynamic Color Code
                    Expanded(
                      flex: 4,
                      child: RepaintBoundary(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(end: _engine.speedKmh),
                          duration: const Duration(milliseconds: 140),
                          curve: Curves.easeOutCubic,
                          builder: (BuildContext context, double spd, _) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: speedColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF2B1105),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    '${spd.round()} km/h',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15.0,
                                      fontWeight: FontWeight.w900,
                                      color: speedColor,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    // Interpolated Live Score & Blossoms
                    Expanded(
                      flex: 5,
                      child: RepaintBoundary(
                        child: TweenAnimationBuilder<double>(
                          tween:
                              Tween<double>(end: _engine.liveScore.toDouble()),
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          builder: (BuildContext context, double sc, _) {
                            return Text(
                              '${sc.round()} pts • ${_engine.blossomsCollected} fl.',
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.8,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF2B1105),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      key: const Key('hud_pause_button'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _engine.togglePause();
                      },
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _engine.isPaused
                                ? const Color(0xFF00E676)
                                : const Color(0xFF80D8FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF2B1105),
                              width: 2.0,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              _engine.isPaused
                                  ? Icons.play_arrow_rounded
                                  : Icons.pause_rounded,
                              size: 18,
                              color: const Color(0xFF2B1105),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      key: const Key('hud_menu_button'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _engine.returnToMainMenu();
                      },
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 46,
                          minHeight: 40,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF2B1105),
                              width: 2.0,
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'MENU',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF2B1105),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Track Progress Bar (0 m -> 1200/1800/2500 m) with Finish Flag + Active Vivienne Anim & Trick Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xDD2B1105),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white24,
                    width: 1.4,
                  ),
                ),
                child: Column(
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              if (isAirborne) ...<Widget>[
                                const SkiCartoonEmblemBadge(
                                  kind: SkiCartoonEmblemKind.jumpTrickStar,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                              ],
                              Flexible(
                                child: Text(
                                  _engine.activeHudStatusLabel,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: _engine.activeHudBadgeColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              '${_engine.playerZ.round()} / ${track.lengthMeters.round()} m',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.flag_rounded,
                              size: 14,
                              color: Color(0xFFFFD700),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _engine.trackProgress,
                        minHeight: 8,
                        backgroundColor: Colors.white24,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(track.badgeColor),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Thumb-Zone Bottom Controls: Touch Steer Left / Accelerometer Tilt Gauge / Touch Steer Right
          Row(
            children: <Widget>[
              Listener(
                key: const Key('touch_steer_left_button'),
                onPointerDown: (_) {
                  HapticFeedback.selectionClick();
                  _engine.setManualTilt(-0.85);
                },
                onPointerUp: (_) => _engine.clearManualTilt(),
                onPointerCancel: (_) => _engine.clearManualTilt(),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 58,
                    minHeight: 54,
                  ),
                  child: Container(
                    width: 62,
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xEEFFF8E7),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFF2B1105),
                        width: 2.6,
                      ),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0xFF4A2511),
                          blurRadius: 0,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.chevron_left_rounded,
                        size: 34,
                        color: Color(0xFF2B1105),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xE02B1105),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFFFFD700),
                      width: 2.0,
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      const SkiCartoonEmblemBadge(
                        kind: SkiCartoonEmblemKind.accelerometerTilt,
                        size: 24,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          height: 16,
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Align(
                            alignment: Alignment(_engine.effectiveTiltX, 0.0),
                            child: Container(
                              width: 22,
                              height: 11,
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E676),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        key: const Key('calibrate_accelerometer_button'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _engine.calibrateAccelerometer();
                        },
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 36,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFF2B1105),
                                width: 1.6,
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                'CALIBRER',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF2B1105),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Listener(
                key: const Key('touch_steer_right_button'),
                onPointerDown: (_) {
                  HapticFeedback.selectionClick();
                  _engine.setManualTilt(0.85);
                },
                onPointerUp: (_) => _engine.clearManualTilt(),
                onPointerCancel: (_) => _engine.clearManualTilt(),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 58,
                    minHeight: 54,
                  ),
                  child: Container(
                    width: 62,
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xEEFFF8E7),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFF2B1105),
                        width: 2.6,
                      ),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0xFF4A2511),
                          blurRadius: 0,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 34,
                        color: Color(0xFF2B1105),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Highscores Leaderboard Modal (`highscores_modal_overlay`)
  // ---------------------------------------------------------------------------

  Widget _buildHighscoresOverlay() {
    final SkiTrackId activeFilter =
        _engine.highscoresFilterTrack ?? _engine.selectedTrack;
    final List<SkiHighscoreEntry> entries =
        _engine.highscoresForTrack(activeFilter);

    return Container(
      key: const Key('highscores_modal_overlay'),
      color: const Color(0x88000000),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.88, end: 1.0),
          duration: const Duration(milliseconds: 220),
          curve: Curves.elasticOut,
          builder: (BuildContext context, double scale, Widget? child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E7),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFF2B1105), width: 3.2),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0xFF4A2511),
                  blurRadius: 0,
                  offset: Offset(0, 7),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const _CartoonSnowCapDecoration(height: 12),
                  const SizedBox(height: 4),
                  Row(
                    children: <Widget>[
                      const SkiCartoonEmblemBadge(
                        kind: SkiCartoonEmblemKind.skiTrophyCup,
                        size: 32,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'TABLEAU DES SCORES',
                          style: TextStyle(
                            fontSize: 18.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2B1105),
                          ),
                        ),
                      ),
                      JuicySki3DButton(
                        key: const Key('close_highscores_button'),
                        backgroundColor: const Color(0xFFFF8A80),
                        lipColor: const Color(0xFFC62828),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        onTap: () => _engine.closeHighscores(),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: Color(0xFF2B1105),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Track Filter Tabs (Verte, Bleue, Noire Or)
                  Row(
                    children: SkiTrackId.values.map((SkiTrackId t) {
                      final bool sel = activeFilter == t;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: GestureDetector(
                            key: Key('filter_highscores_${t.id}'),
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _engine.setHighscoresFilterTrack(t);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: sel ? t.badgeColor : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFF2B1105),
                                  width: sel ? 2.4 : 1.6,
                                ),
                              ),
                              child: Text(
                                t.shortTitle,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                  color: sel &&
                                          t == SkiTrackId.blueAsnieresForest
                                      ? Colors.white
                                      : const Color(0xFF2B1105),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),

                  // Gold / Silver / Bronze Medal Rows
                  for (int i = 0; i < math.min(5, entries.length); i++)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: entries[i].isPlayerRun
                            ? const Color(0xFFFFF3C4)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF2B1105),
                          width: 1.8,
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: i == 0
                                  ? const Color(0xFFFFD700) // Gold
                                  : (i == 1
                                      ? const Color(0xFFCFD8DC) // Silver
                                      : (i == 2
                                          ? const Color(0xFFFFB74D) // Bronze
                                          : const Color(0xFFEEEEEE))),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF2B1105),
                                width: 1.8,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                i == 0
                                    ? 'OR'
                                    : (i == 1
                                        ? 'ARG'
                                        : (i == 2 ? 'BRZ' : '#${i + 1}')),
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF2B1105),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  entries[i].playerName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF2B1105),
                                  ),
                                ),
                                Row(
                                  children: <Widget>[
                                    Text(
                                      '${entries[i].timeSeconds.toStringAsFixed(1)}s • Saut ${entries[i].maxJumpMeters.toStringAsFixed(1)}m • ',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF5D4037),
                                      ),
                                    ),
                                    for (int s = 0; s < entries[i].stars; s++)
                                      const Icon(
                                        Icons.star_rounded,
                                        size: 12,
                                        color: Color(0xFFFFB300),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${entries[i].score} pts',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF8B1E24),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),

                  SizedBox(
                    width: double.infinity,
                    child: JuicySki3DButton(
                      key: const Key('ski_this_track_from_leaderboard_button'),
                      backgroundColor: const Color(0xFF00E676),
                      lipColor: const Color(0xFF008E46),
                      onTap: () => _engine.startRun(track: activeFilter),
                      child: Text(
                        'SKIER CETTE PISTE (${activeFilter.shortTitle.toUpperCase()}) !',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2B1105),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Vivienne 360° Turntable 3D Gallery (`vivienne_gallery_panel`)
  // ---------------------------------------------------------------------------

  Widget _buildTurntableGalleryOverlay() {
    final VivienneSkiEdition activeEdition = _engine.selectedEdition;

    return Container(
      key: const Key('vivienne_gallery_panel'),
      color: const Color(0x99000000),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.88, end: 1.0),
          duration: const Duration(milliseconds: 220),
          curve: Curves.elasticOut,
          builder: (BuildContext context, double scale, Widget? child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E7),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFF2B1105), width: 3.2),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0xFF4A2511),
                  blurRadius: 0,
                  offset: Offset(0, 7),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const _CartoonSnowCapDecoration(height: 12),
                  const SizedBox(height: 4),
                  Row(
                    children: <Widget>[
                      const SkiCartoonEmblemBadge(
                        kind: SkiCartoonEmblemKind.turntableGallery,
                        size: 32,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'GALERIE 3D VOLUMÉTRIQUE',
                          style: TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2B1105),
                          ),
                        ),
                      ),
                      JuicySki3DButton(
                        key: const Key('close_turntable_gallery_button'),
                        backgroundColor: const Color(0xFFFF8A80),
                        lipColor: const Color(0xFFC62828),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        onTap: () => _engine.closeTurntableGallery(),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: Color(0xFF2B1105),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 3 Official BLENDER_LAB Vivienne Models Selector Row inside Gallery
                  Row(
                    children:
                        VivienneSkiEdition.values.map((VivienneSkiEdition ed) {
                      final bool sel = activeEdition == ed;
                      final String label = switch (ed) {
                        VivienneSkiEdition.speedyV03 => 'Speedy v03',
                        VivienneSkiEdition.wonderland => 'Wonderland',
                        VivienneSkiEdition.giantDenim => 'Giant Denim',
                      };
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: GestureDetector(
                            key: Key('gallery_select_edition_${ed.id}'),
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _engine.selectEdition(ed);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: sel
                                    ? const Color(0xFFFFD700)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF2B1105),
                                  width: sel ? 2.2 : 1.5,
                                ),
                              ),
                              child: Text(
                                label,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 9.8,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF2B1105),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),

                  Container(
                    height: 224,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const RadialGradient(
                        colors: <Color>[Color(0xFFFFFFFF), Color(0xFFB3E5FC)],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0xFF2B1105),
                        width: 2.4,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 22, 8, 4),
                            child: Vivienne3DViewport(
                              key: const Key('gallery_vivienne_3d_viewport'),
                              edition: activeEdition,
                              yawDegrees: _engine.turntableAngleDegrees,
                              mode: VivienneMotionMode.showcase360,
                              externalTimeSeconds: _engine.ambientTime,
                              includeSkisAndPoles: true,
                              onHorizontalDragYawDelta: (double delta) {
                                _engine.rotateTurntableBy(delta);
                              },
                            ),
                          ),
                        ),
                        Positioned(
                          top: 7,
                          left: 10,
                          right: 10,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1638E8),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFFFFD700),
                                      width: 1.4,
                                    ),
                                  ),
                                  child: Text(
                                    '${activeEdition.blendPath} • 22 OS 3D',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFD700),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFF2B1105),
                                    width: 1.4,
                                  ),
                                ),
                                child: Text(
                                  '${_engine.turntableAngleDegrees.round()}°',
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF2B1105),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${activeEdition.name} • ${activeEdition.subtitle}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12.2,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2B1105),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _engine.turntableAngleLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10.8,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF8B1E24),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Glissez sur 360° ou inclinez le téléphone : volume 3D complet & membres animés',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10.0,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF5D4037),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: JuicySki3DButton(
                          key: const Key('turntable_rotate_left_button'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 10,
                          ),
                          onTap: () => _engine.rotateTurntableBy(-15.0),
                          child: const Text(
                            '-15°',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 2,
                        child: JuicySki3DButton(
                          key: const Key('turntable_rear_180_button'),
                          backgroundColor: const Color(0xFF80D8FF),
                          lipColor: const Color(0xFF0277BD),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 10,
                          ),
                          onTap: () => _engine.setTurntableAngle(180.0),
                          child: const Text(
                            'DOS 180° (SKI)',
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: JuicySki3DButton(
                          key: const Key('turntable_rotate_right_button'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 10,
                          ),
                          onTap: () => _engine.rotateTurntableBy(15.0),
                          child: const Text(
                            '+15°',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // In-Run Pause Modal (`pause_modal_overlay`) with 3/4-Profile (~60°) 3D Inspection
  // ---------------------------------------------------------------------------

  Widget _buildPauseOverlay() {
    final SkiTrackId track = _engine.selectedTrack;
    final VivienneSkiEdition ed = _engine.selectedEdition;

    return Container(
      key: const Key('pause_modal_overlay'),
      color: const Color(0x88000000),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.88, end: 1.0),
          duration: const Duration(milliseconds: 220),
          curve: Curves.elasticOut,
          builder: (BuildContext context, double scale, Widget? child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(15, 8, 15, 15),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E7),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFF2B1105), width: 3.2),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0xFF4A2511),
                  blurRadius: 0,
                  offset: Offset(0, 7),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const _CartoonSnowCapDecoration(height: 12),
                  const SizedBox(height: 4),
                  const Text(
                    'COURSE EN PAUSE',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2B1105),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${track.title} • ${ed.name}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11.4,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1638E8),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Interactive 3/4-Profile (~60°) 3D Volumetric Inspection Stage
                  Container(
                    height: 158,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const RadialGradient(
                        colors: <Color>[Color(0xFFFFFFFF), Color(0xFFB3E5FC)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF2B1105),
                        width: 2.2,
                      ),
                    ),
                    child: Stack(
                      children: <Widget>[
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 22, 8, 4),
                            child: Vivienne3DViewport(
                              key: const Key('pause_vivienne_3d_viewport'),
                              edition: ed,
                              yawDegrees: _pauseInspectionYawDegrees,
                              mode: VivienneMotionMode.pauseInspection,
                              externalTimeSeconds:
                                  _engine.ambientTime + _engine.elapsedSeconds,
                              includeSkisAndPoles: true,
                              onHorizontalDragYawDelta: (double delta) {
                                setState(() {
                                  _pauseInspectionYawDegrees =
                                      ((_pauseInspectionYawDegrees + delta) %
                                                  360.0 +
                                              360.0) %
                                          360.0;
                                });
                              },
                            ),
                          ),
                        ),
                        Positioned(
                          top: 6,
                          left: 8,
                          right: 8,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1638E8),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFFFD700),
                                    width: 1.3,
                                  ),
                                ),
                                child: Text(
                                  'INSPECTION 3D • ${_pauseInspectionYawDegrees.round()}° (3/4 PROFIL)',
                                  style: const TextStyle(
                                    fontSize: 9.0,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    Icons.threesixty_rounded,
                                    size: 13,
                                    color: Color(0xFF2B1105),
                                  ),
                                  SizedBox(width: 2),
                                  Text(
                                    '360°',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF2B1105),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF2B1105),
                        width: 2.0,
                      ),
                    ),
                    child: Column(
                      children: <Widget>[
                        _buildScoreDetailRow(
                          'Score en cours',
                          '${_engine.liveScore} pts',
                        ),
                        _buildScoreDetailRow(
                          'Progression piste',
                          '${_engine.playerZ.round()} / ${track.lengthMeters.round()} m',
                        ),
                        _buildScoreDetailRow(
                          'Fleurs Blossom • Vitesse',
                          '${_engine.blossomsCollected} fl. • ${_engine.speedKmh.round()} km/h',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: JuicySki3DButton(
                      key: const Key('resume_run_button'),
                      backgroundColor: const Color(0xFF00E676),
                      lipColor: const Color(0xFF008E46),
                      onTap: () => _engine.setPaused(false),
                      child: const Text(
                        'REPRENDRE LA DESCENTE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: JuicySki3DButton(
                          key: const Key('pause_restart_button'),
                          backgroundColor: const Color(0xFFFFD700),
                          lipColor: const Color(0xFFB26A00),
                          onTap: () => _engine.restartCurrentTrack(),
                          child: const Text(
                            'RECOMMENCER',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: JuicySki3DButton(
                          key: const Key('pause_menu_return_button'),
                          backgroundColor: const Color(0xFF80D8FF),
                          lipColor: const Color(0xFF0277BD),
                          onTap: () => _engine.returnToMainMenu(),
                          child: const Text(
                            'MENU ACCUEIL',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // End-of-Track Chalet Arrival Modal (`track_finished_overlay`)
  // ---------------------------------------------------------------------------

  Widget _buildTrackFinishedOverlay() {
    final SkiScoreBreakdown? b = _engine.lastRunBreakdown;
    final int stars = b?.starsEarned ?? 3;
    final int rank = _engine.lastRunRank ?? 1;

    return Container(
      key: const Key('track_finished_overlay'),
      color: const Color(0x88000000),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.85, end: 1.0),
          duration: const Duration(milliseconds: 260),
          curve: Curves.elasticOut,
          builder: (BuildContext context, double scale, Widget? child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E7),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFF2B1105), width: 3.2),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0xFF4A2511),
                  blurRadius: 0,
                  offset: Offset(0, 7),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const _CartoonSnowCapDecoration(height: 12),
                  const SizedBox(height: 4),
                  const Text(
                    'ARRIVÉE AU CHALET !',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2B1105),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // 3D Volumetric Podium Celebration Stage (Arms Raised in V!)
                  Container(
                    height: 122,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const RadialGradient(
                        colors: <Color>[Color(0xFFFFFFFF), Color(0xFFFFECB3)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFF2B1105),
                        width: 2.2,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Vivienne3DViewport(
                              key: const Key('podium_vivienne_3d_viewport'),
                              edition: _engine.selectedEdition,
                              yawDegrees: 28.0,
                              mode: VivienneMotionMode.podiumCelebration,
                              externalTimeSeconds:
                                  _engine.ambientTime + _engine.elapsedSeconds,
                              includeSkisAndPoles: true,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 6,
                          right: 8,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List<Widget>.generate(3, (int idx) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                child: Opacity(
                                  opacity: idx < stars ? 1.0 : 0.25,
                                  child: const SkiCartoonEmblemBadge(
                                    kind: SkiCartoonEmblemKind.jumpTrickStar,
                                    size: 24,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _engine.lastRunIsNewRecord
                          ? const Color(0xFFFFD700)
                          : const Color(0xFFE1F5FE),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF2B1105),
                        width: 1.8,
                      ),
                    ),
                    child: Text(
                      _engine.lastRunIsNewRecord
                          ? 'NOUVEAU RECORD ! • RANG #$rank (${_engine.selectedTrack.shortTitle})'
                          : 'CLASSEMENT PISTE : RANG #$rank (${_engine.selectedTrack.shortTitle})',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF2B1105),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'SCORE TOTAL : ${b?.totalScore ?? _engine.liveScore} PTS',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF8B1E24),
                    ),
                  ),
                  if (b != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF2B1105),
                          width: 1.8,
                        ),
                      ),
                      child: Column(
                        children: <Widget>[
                          _buildScoreDetailRow(
                            'Points Glisse (${_engine.selectedTrack.lengthMeters.round()} m)',
                            '+${b.distancePoints} pts',
                          ),
                          _buildScoreDetailRow(
                            'Fleurs Blossom (${b.blossomsCollected})',
                            '+${b.blossomPoints} pts',
                          ),
                          _buildScoreDetailRow(
                            'Portes de Slalom (${b.slalomPassed})',
                            '+${b.slalomPoints} pts',
                          ),
                          _buildScoreDetailRow(
                            'Figures de Saut & Bosses (${b.jumpsCompleted} sauts • ${b.mogulsAbsorbed} bosses)',
                            '+${b.jumpAndMogulPoints} pts',
                          ),
                          _buildScoreDetailRow(
                            'Bonus Chrono (${b.elapsedSeconds.toStringAsFixed(1)}s)',
                            '+${b.chronoBonusPoints} pts',
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: JuicySki3DButton(
                          key: const Key('replay_track_button'),
                          backgroundColor: const Color(0xFFFFD700),
                          lipColor: const Color(0xFFB26A00),
                          onTap: () => _engine.restartCurrentTrack(),
                          child: const Text(
                            'REJOUER LA PISTE',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: JuicySki3DButton(
                          key: const Key('next_track_button'),
                          backgroundColor: const Color(0xFF00E676),
                          lipColor: const Color(0xFF008E46),
                          onTap: () => _engine.startNextTrack(),
                          child: const Text(
                            'PISTE SUIVANTE',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: JuicySki3DButton(
                      key: const Key('finish_return_menu_button'),
                      backgroundColor: const Color(0xFF80D8FF),
                      lipColor: const Color(0xFF0277BD),
                      onTap: () => _engine.returnToMainMenu(),
                      child: const Text(
                        'MENU D\'ACCUEIL',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScoreDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.2,
                fontWeight: FontWeight.w700,
                color: Color(0xFF5D4037),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              color: Color(0xFF2B1105),
            ),
          ),
        ],
      ),
    );
  }
}
