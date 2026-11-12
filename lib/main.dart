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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
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

/// Tactile 3D Cartoon Button implementing `mobile-game-ui` v1.2.0 (Mode B Flutter).
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
          scale: _pressed ? 0.93 : 1.0,
          duration: Duration(milliseconds: _pressed ? 70 : 180),
          curve: _pressed ? Curves.easeOutCubic : Curves.elasticOut,
          child: Transform.translate(
            offset: Offset(0, dy),
            child: Container(
              padding: widget.padding,
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
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class ViviAuSkiApp extends StatelessWidget {
  const ViviAuSkiApp({
    super.key,
    this.engine,
    this.initialTurntableSprites,
    this.initialPoseSprites,
    this.autoStartTicker = true,
    this.screenshotBoundaryKey,
  });

  final SkiGameEngine? engine;
  final List<ui.Image?>? initialTurntableSprites;
  final Map<VivienneBlenderPose, ui.Image>? initialPoseSprites;
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
        initialTurntableSprites: initialTurntableSprites,
        initialPoseSprites: initialPoseSprites,
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
    this.initialTurntableSprites,
    this.initialPoseSprites,
    this.autoStartTicker = true,
    this.screenshotBoundaryKey,
  });

  final SkiGameEngine? engine;
  final List<ui.Image?>? initialTurntableSprites;
  final Map<VivienneBlenderPose, ui.Image>? initialPoseSprites;
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

  final List<ui.Image?> _turntableSprites = List<ui.Image?>.filled(
    VivienneTurntableSpec.frameCount,
    null,
  );
  final Map<VivienneBlenderPose, ui.Image> _poseSprites =
      <VivienneBlenderPose, ui.Image>{};

  @override
  void initState() {
    super.initState();
    _ownsEngine = widget.engine == null;
    _engine = widget.engine ??
        SkiGameEngine(
          onHapticEvent: _triggerHaptic,
        );
    _keyboardFocusNode = FocusNode();

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

    if (widget.autoStartTicker) {
      _subscribeHardwareAccelerometer();
      _ticker = createTicker(_onTick)..start();
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
                  turntableSprites: _turntableSprites,
                  poseSprites: _poseSprites,
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
    return Container(
      key: const Key('main_menu_overlay'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(14),
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
                // Header Banner
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: <Color>[Color(0xFF29B6F6), Color(0xFF0277BD)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: const Color(0xFF2B1105), width: 2.6),
                  ),
                  child: const Column(
                    children: <Widget>[
                      Text(
                        'VIVI AU SKI 3D',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'DESCENTE ROYALE • ACCÉLÉROMÈTRE & BOSSES 3D',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFFF59D),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // 4 Vivienne Ski Editions Compact Selector
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: VivienneSkiEdition.values.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (BuildContext context, int index) {
                      final VivienneSkiEdition ed =
                          VivienneSkiEdition.values[index];
                      final bool selected = _engine.selectedEdition == ed;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _engine.selectEdition(ed);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFFFFD700)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF2B1105),
                              width: selected ? 2.4 : 1.6,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              ed.name.replaceFirst('Vivienne ', ''),
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF2B1105),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),

                // 3 Ski Tracks Selection Cards
                for (final SkiTrackId track in SkiTrackId.values) ...<Widget>[
                  _buildTrackCard(track),
                  const SizedBox(height: 8),
                ],

                const SizedBox(height: 4),

                // Primary Play Button: DÉVALER LA PISTE !
                SizedBox(
                  width: double.infinity,
                  child: JuicySki3DButton(
                    key: const Key('start_ski_run_button'),
                    backgroundColor: const Color(0xFF00E676),
                    lipColor: const Color(0xFF008E46),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    onTap: () => _engine.startRun(),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        SkiCartoonEmblemBadge(
                          kind: SkiCartoonEmblemKind.playSkiTriangle,
                          size: 28,
                        ),
                        SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'DÉVALER LA PISTE !',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF2B1105),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Secondary Action Row: TABLEAU DES SCORES & GALERIE VIVIENNE 3D
                Row(
                  children: <Widget>[
                    Expanded(
                      child: JuicySki3DButton(
                        key: const Key('open_highscores_button'),
                        backgroundColor: const Color(0xFFFFD700),
                        lipColor: const Color(0xFFB26A00),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        onTap: () => _engine.openHighscores(),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            SkiCartoonEmblemBadge(
                              kind: SkiCartoonEmblemKind.skiTrophyCup,
                              size: 24,
                            ),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'SCORES',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF2B1105),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: JuicySki3DButton(
                        key: const Key('open_turntable_gallery_button'),
                        backgroundColor: const Color(0xFF80D8FF),
                        lipColor: const Color(0xFF0277BD),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        onTap: () => _engine.openTurntableGallery(),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            SkiCartoonEmblemBadge(
                              kind: SkiCartoonEmblemKind.turntableGallery,
                              size: 24,
                            ),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'GALERIE 3D',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF3C4) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFF2B1105),
            width: isSelected ? 3.0 : 2.0,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: isSelected ? track.badgeLipColor : const Color(0x22000000),
              blurRadius: 0,
              offset: Offset(0, isSelected ? 4 : 2),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            SkiCartoonEmblemBadge(kind: _emblemForTrack(track), size: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    track.difficultyLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: track.badgeLipColor,
                    ),
                  ),
                  Text(
                    track.title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2B1105),
                    ),
                  ),
                  Text(
                    track.summaryMetrics,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF5D4037),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2B1105),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$best pts',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFFD700),
                ),
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          // Top HUD Bar: Speed, Progress, Score & Menu/Calibrate
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xE8FFF8E7),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: const Color(0xFF2B1105), width: 2.6),
                ),
                child: Row(
                  children: <Widget>[
                    // Interpolated Speed Counter (km/h)
                    Expanded(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(end: _engine.speedKmh),
                        duration: const Duration(milliseconds: 140),
                        builder: (BuildContext context, double spd, _) {
                          return Text(
                            '${spd.round()} km/h',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0277BD),
                            ),
                          );
                        },
                      ),
                    ),
                    // Interpolated Live Score & Blossoms
                    Expanded(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(end: _engine.liveScore.toDouble()),
                        duration: const Duration(milliseconds: 180),
                        builder: (BuildContext context, double sc, _) {
                          return Text(
                            '${sc.round()} pts • ${_engine.blossomsCollected} fl.',
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF2B1105),
                            ),
                          );
                        },
                      ),
                    ),
                    GestureDetector(
                      key: const Key('hud_menu_button'),
                      onTap: () => _engine.returnToMainMenu(),
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 36,
                        ),
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
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Track Progress Bar + Active Vivienne Anim Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xD82B1105),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            _engine.animState.label,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: _engine.animState.badgeColor,
                            ),
                          ),
                        ),
                        Text(
                          '${_engine.playerZ.round()} / ${track.lengthMeters.round()} m',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: <Widget>[
                Listener(
                  key: const Key('touch_steer_left_button'),
                  onPointerDown: (_) => _engine.setManualTilt(-0.85),
                  onPointerUp: (_) => _engine.clearManualTilt(),
                  onPointerCancel: (_) => _engine.clearManualTilt(),
                  child: Container(
                    width: 64,
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xE6FFF8E7),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFF2B1105),
                        width: 2.5,
                      ),
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
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xD92B1105),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFFFD700),
                        width: 1.8,
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
                          child: Align(
                            alignment:
                                Alignment(_engine.effectiveTiltX, 0.0),
                            child: Container(
                              width: 20,
                              height: 12,
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E676),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          key: const Key('calibrate_accelerometer_button'),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _engine.calibrateAccelerometer();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'CALIBRER',
                              style: TextStyle(
                                fontSize: 10,
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
                const SizedBox(width: 8),
                Listener(
                  key: const Key('touch_steer_right_button'),
                  onPointerDown: (_) => _engine.setManualTilt(0.85),
                  onPointerUp: (_) => _engine.clearManualTilt(),
                  onPointerCancel: (_) => _engine.clearManualTilt(),
                  child: Container(
                    width: 64,
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xE6FFF8E7),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFF2B1105),
                        width: 2.5,
                      ),
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
              ],
            ),
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
            padding: const EdgeInsets.all(14),
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
                            fontSize: 19,
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

                  // Track Filter Tabs
                  Row(
                    children: SkiTrackId.values.map((SkiTrackId t) {
                      final bool sel = activeFilter == t;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: GestureDetector(
                            onTap: () => _engine.setHighscoresFilterTrack(t),
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
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: i == 0
                                  ? const Color(0xFFFFD700)
                                  : (i == 1
                                      ? const Color(0xFFCFD8DC)
                                      : (i == 2
                                          ? const Color(0xFFFFB74D)
                                          : const Color(0xFFEEEEEE))),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF2B1105),
                                width: 1.6,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '#${i + 1}',
                                style: const TextStyle(
                                  fontSize: 11,
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
                                Text(
                                  '${entries[i].timeSeconds.toStringAsFixed(1)}s • Saut ${entries[i].maxJumpMeters.toStringAsFixed(1)}m',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF5D4037),
                                  ),
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
                        'SKIER : ${activeFilter.shortTitle.toUpperCase()} !',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
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
    final int idx = _engine.turntableFrameIndex;
    final ui.Image? frameImage =
        (idx >= 0 && idx < _turntableSprites.length)
            ? _turntableSprites[idx]
            : null;

    return Container(
      key: const Key('vivienne_gallery_panel'),
      color: const Color(0x99000000),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E7),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFF2B1105), width: 3.2),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const SkiCartoonEmblemBadge(
                      kind: SkiCartoonEmblemKind.turntableGallery,
                      size: 32,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'GALERIE VIVIENNE 3D (360°)',
                        style: TextStyle(
                          fontSize: 17,
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
                const SizedBox(height: 10),
                GestureDetector(
                  onHorizontalDragUpdate: (DragUpdateDetails d) {
                    _engine.rotateTurntableBy(d.delta.dx * 1.2);
                  },
                  child: Container(
                    height: 230,
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
                    child: Center(
                      child: frameImage != null
                          ? RawImage(image: frameImage, fit: BoxFit.contain)
                          : Image.asset(
                              VivienneTurntableSpec.assetPathForIndex(idx),
                              fit: BoxFit.contain,
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _engine.turntableAngleLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2B1105),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Inclinez votre téléphone ou glissez pour tourner Vivienne à 360° (vivienne_speedy_v03.blend)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF5D4037),
                  ),
                ),
                const SizedBox(height: 10),
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
    );
  }

  // ---------------------------------------------------------------------------
  // End-of-Track Chalet Arrival Modal (`track_finished_overlay`)
  // ---------------------------------------------------------------------------

  Widget _buildTrackFinishedOverlay() {
    final SkiScoreBreakdown? b = _engine.lastRunBreakdown;
    final int stars = b?.starsEarned ?? 3;

    return Container(
      key: const Key('track_finished_overlay'),
      color: const Color(0x88000000),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.85, end: 1.0),
          duration: const Duration(milliseconds: 240),
          curve: Curves.elasticOut,
          builder: (BuildContext context, double scale, Widget? child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E7),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFF2B1105), width: 3.2),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text(
                    'ARRIVÉE AU CHALET !',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2B1105),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List<Widget>.generate(3, (int idx) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Opacity(
                          opacity: idx < stars ? 1.0 : 0.25,
                          child: const SkiCartoonEmblemBadge(
                            kind: SkiCartoonEmblemKind.jumpTrickStar,
                            size: 36,
                          ),
                        ),
                      );
                    }),
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
                    const SizedBox(height: 6),
                    Text(
                      'Fleurs Blossom : +${b.blossomPoints} • Slalom : +${b.slalomPoints}\nFigures & Bosses : +${b.jumpAndMogulPoints} • Bonus Chrono : +${b.chronoBonusPoints}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF5D4037),
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
                            'REJOUER',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.w900),
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
                            style: TextStyle(fontWeight: FontWeight.w900),
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
                        style: TextStyle(fontWeight: FontWeight.w900),
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
}
