import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/ski_models.dart';

enum SkiHapticEvent {
  carveEdge,
  mogulBump,
  rampLaunch,
  landingImpact,
  slalomGate,
  blossomPickup,
  obstacleBounce,
  trackFinished,
}

/// Real-time 60–120 FPS 3D Cartoon Ski Simulation & Accelerometer Engine
/// for `VIVI AU SKI : Descente Royale 3D` (`v1.5.0`).
class SkiGameEngine extends ChangeNotifier {
  SkiGameEngine({
    SkiTrackId initialTrack = SkiTrackId.greenBlossomValley,
    VivienneSkiEdition initialEdition = VivienneSkiEdition.speedyV03,
    SkiGameMode initialGameMode = SkiGameMode.descenteBosses,
    int seed = 2026,
    this.onHapticEvent,
  })  : _selectedTrack = initialTrack,
        _selectedEdition = initialEdition,
        _selectedGameMode = initialGameMode,
        _seed = seed {
    _seedDefaultHighscores();
    _generateTrackWorld(_selectedTrack, _seed);
    _initAmbientSnowflakes();
  }

  final void Function(SkiHapticEvent event)? onHapticEvent;

  // Navigation & Modal States
  bool isInMenu = true;
  bool isHighscoresOpen = false;
  bool isTurntableGalleryOpen = false;
  bool isTrackFinished = false;
  bool isPaused = false;

  SkiTrackId _selectedTrack;
  SkiTrackId get selectedTrack => _selectedTrack;

  SkiTrackId? _highscoresFilterTrack;
  SkiTrackId? get highscoresFilterTrack => _highscoresFilterTrack;

  VivienneSkiEdition _selectedEdition;
  VivienneSkiEdition get selectedEdition => _selectedEdition;

  SkiGameMode _selectedGameMode;
  SkiGameMode get selectedGameMode => _selectedGameMode;
  bool get isSlalomMode => _selectedGameMode == SkiGameMode.slalomComplet;

  int _seed;
  int get seed => _seed;

  // Hardware Accelerometer & Manual Fallback State
  double rawSensorAx = 0.0;
  double rawSensorAy = 0.0;
  double rawSensorAz = 9.81;
  double calibrationOffsetAx = 0.0;
  bool hasHardwareSensor = false;

  double _rawTargetHardwareTilt = 0.0;
  double _smoothedHardwareTilt = 0.0;
  double _manualTilt = 0.0;
  bool _manualTiltActive = false;

  /// Effective lateral steering input in `[-1.0, 1.0]` (`< 0` = Left, `> 0` = Right).
  double get effectiveTiltX {
    final double raw = _manualTiltActive ? _manualTilt : _smoothedHardwareTilt;
    return raw.clamp(-1.0, 1.0);
  }

  bool get isUsingManualTilt => _manualTiltActive;

  // 360° Cycles Turntable Gallery State
  double turntableAngleDegrees = 180.0;
  int get turntableFrameIndex =>
      VivienneTurntableSpec.frameIndexForAngle(turntableAngleDegrees);
  String get turntableAngleLabel =>
      VivienneTurntableSpec.angleLabelForDegrees(turntableAngleDegrees);

  // 3D Skier Kinematics & Pose State
  double playerZ = 0.0;
  double playerLateralOffset = 0.0;
  double playerY = 0.0;
  double playerVx = 0.0;
  double playerVy = 0.0;
  double speedKmh = 62.0;
  double playerRollRadians = 0.0;

  double get playerWorldX =>
      trackCenterOffsetX(playerZ) + playerLateralOffset;

  double get trackProgress =>
      (playerZ / _selectedTrack.lengthMeters).clamp(0.0, 1.0);

  double get remainingMeters =>
      math.max(0.0, _selectedTrack.lengthMeters - playerZ);

  VivienneSkiAnimState animState = VivienneSkiAnimState.glidingRearNeutral;
  SkiAerialTrickKind currentAerialTrick = SkiAerialTrickKind.none;

  /// Full `0 -> 2π` yaw rotation angle around Y during `SkiAerialTrickKind.saut360`.
  double trickSpinAngle = 0.0;

  /// Full `0 -> 2π` head-over-heels flip angle during `SkiAerialTrickKind.sautPerilleux`.
  double trickFlipAngle = 0.0;

  /// Normalized aerial stunt progress in `[0.0, 1.0]` from takeoff to landing.
  double trickProgress = 0.0;

  double _expectedFlightDuration = 1.15;
  int _rampTrickCounter = 0;

  /// Exact 3D surface elevation (`mogul dome` or `inclined ramp deck`) directly beneath Vivienne's skis.
  double get playerGroundY => groundSurfaceHeightAt(playerWorldX, playerZ);

  bool get isAirborne => (playerY - playerGroundY) > 0.30 || playerVy > 1.2;

  double get carveRate => (playerVx / 18.0).clamp(-1.0, 1.0);

  double get cameraZ => playerZ - 12.0;

  double worldElevationAt(double z) => trackElevationY(z);

  String get activeHudStatusLabel {
    if (isAirborne && currentAerialTrick == SkiAerialTrickKind.saut360) {
      return 'SAUT 360° +${SkiAerialTrickKind.saut360.bonusPoints}';
    }
    if (isAirborne && currentAerialTrick == SkiAerialTrickKind.sautPerilleux) {
      return 'SAUT PÉRILLEUX +${SkiAerialTrickKind.sautPerilleux.bonusPoints}';
    }
    return animState.label;
  }

  Color get activeHudBadgeColor {
    if (isAirborne && currentAerialTrick == SkiAerialTrickKind.saut360) {
      return const Color(0xFFFFD700);
    }
    if (isAirborne && currentAerialTrick == SkiAerialTrickKind.sautPerilleux) {
      return const Color(0xFFFF4081);
    }
    return animState.badgeColor;
  }

  /// Dynamic Blender Cycles pose index (`0..4`) matching the active ski & jump phase:
  /// - `0` (`Pose 1`): Mogul Absorption Squash / Landing Impact Squash
  /// - `1` (`Pose 2`): Standing Schuss Glide & Dynamic Carving
  /// - `2` (`Pose 3`): Takeoff / Ramp Launch Stretch
  /// - `3` (`Pose 4`): Airborne V-Arms Jump
  /// - `4` (`Pose 5`): High-Apex Grand Celebration Jump
  int get activeSkierPoseIndex {
    if (isAirborne) {
      if (_launchStretchTimer > 0.0 ||
          animState == VivienneSkiAnimState.rampLaunchStretch ||
          (playerVy > 6.5 && playerY <= 1.25)) {
        return 2;
      }
      if (playerY > 1.35 || playerVy.abs() <= 3.8) {
        return 4;
      }
      return 3;
    }
    if (_landingSquashTimer > 0.0 ||
        _mogulSquashTimer > 0.0 ||
        animState == VivienneSkiAnimState.landingImpact ||
        animState == VivienneSkiAnimState.mogulAbsorptionSquash) {
      return 0;
    }
    if (_launchStretchTimer > 0.0 ||
        animState == VivienneSkiAnimState.rampLaunchStretch) {
      return 2;
    }
    return 1;
  }

  double currentAnimScaleX = 1.0;
  double currentAnimScaleY = 1.0;
  double armRaiseProgress = 0.08;
  double speedyBagSwingRadians = 0.0;
  double _speedyBagAngularVel = 0.0;
  double scarfWavePhase = 0.0;
  double ambientTime = 0.55;

  static const double snowballCrashDuration = 1.15;
  double snowballCrashTimer = 0.0;
  double snowballRotationRadians = 0.0;
  PineCollisionZone? lastPineCollisionZone;

  bool get isInSnowballCrash =>
      snowballCrashTimer > 0.0 ||
      animState == VivienneSkiAnimState.snowballCrash;

  double get snowballCrashProgress => snowballCrashTimer > 0.0
      ? (1.0 - (snowballCrashTimer / snowballCrashDuration)).clamp(0.0, 1.0)
      : 0.0;

  double _mogulSquashTimer = 0.0;
  double _launchStretchTimer = 0.0;
  double _landingSquashTimer = 0.0;
  double _stumbleTimer = 0.0;
  double _stumbleCooldown = 0.0;
  double _speedBoostTimer = 0.0;

  // Run Metrics & Score State
  double elapsedSeconds = 0.0;
  double airtimeSeconds = 0.0;
  double totalAirtimeSeconds = 0.0;
  double currentJumpHeightMeters = 0.0;
  double maxJumpHeightMeters = 0.0;

  int blossomsCollected = 0;
  int blossomPoints = 0;
  int slalomPassed = 0;
  int slalomCombo = 0;
  int maxSlalomCombo = 0;
  int slalomPoints = 0;
  int mogulsAbsorbed = 0;
  int jumpsCompleted = 0;
  int jumpAndMogulPoints = 0;

  int get distancePoints => (playerZ * 1.5).round();

  int get liveScore {
    final int raw =
        distancePoints + blossomPoints + slalomPoints + jumpAndMogulPoints;
    return (raw * _selectedEdition.scoreMultiplier).round();
  }

  SkiScoreBreakdown? lastRunBreakdown;
  int? lastRunRank;
  bool lastRunIsNewRecord = false;

  // Generated 3D World Collections
  final List<SkiWorldProp3D> worldProps = <SkiWorldProp3D>[];
  final List<SkiMogul3D> moguls = <SkiMogul3D>[];
  final List<SkiJumpRamp3D> jumpRamps = <SkiJumpRamp3D>[];
  final List<SkiSlalomGate3D> slalomGates = <SkiSlalomGate3D>[];
  final List<SkiBlossomCollectible3D> blossoms = <SkiBlossomCollectible3D>[];
  final List<SkiSnowParticle3D> snowParticles = <SkiSnowParticle3D>[];
  final List<SkiTrackRibbonPoint> skiTrailHistory = <SkiTrackRibbonPoint>[];
  final List<SkiFloatingCallout> callouts = <SkiFloatingCallout>[];
  final List<SkiHighscoreEntry> _highscores = <SkiHighscoreEntry>[];

  List<SkiHighscoreEntry> get highscores =>
      List<SkiHighscoreEntry>.unmodifiable(_highscores);

  List<SkiHighscoreEntry> highscoresForTrack(SkiTrackId? track) {
    final Iterable<SkiHighscoreEntry> filtered = track == null
        ? _highscores
        : _highscores.where((SkiHighscoreEntry e) => e.trackId == track);
    final List<SkiHighscoreEntry> sorted = filtered.toList()
      ..sort((SkiHighscoreEntry a, SkiHighscoreEntry b) =>
          b.score.compareTo(a.score));
    return sorted;
  }

  int bestScoreForTrack(SkiTrackId track) {
    final List<SkiHighscoreEntry> list = highscoresForTrack(track);
    return list.isEmpty ? 0 : list.first.score;
  }

  List<SkiWorldProp3D> get spectatorProps => worldProps
      .where(
        (SkiWorldProp3D p) =>
            p.kind == SkiPropKind.vivienneSpectator ||
            p.kind == SkiPropKind.flutteringPennantPost,
      )
      .toList(growable: false);

  SkiSlalomGate3D? get nextUpcomingSlalomGate {
    for (int i = 0; i < slalomGates.length; i++) {
      final SkiSlalomGate3D g = slalomGates[i];
      if (!g.passed && !g.missed && g.z >= playerZ - 2.0) {
        return g;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Navigation & Selection Controls
  // ---------------------------------------------------------------------------

  void selectTrack(SkiTrackId track) {
    if (_selectedTrack == track && worldProps.isNotEmpty) {
      notifyListeners();
      return;
    }
    _selectedTrack = track;
    _generateTrackWorld(_selectedTrack, _seed);
    _resetSkierKinematics();
    notifyListeners();
  }

  void selectEdition(VivienneSkiEdition edition) {
    _selectedEdition = edition;
    notifyListeners();
  }

  void selectGameMode(SkiGameMode mode) {
    if (_selectedGameMode == mode && slalomGates.isNotEmpty) {
      notifyListeners();
      return;
    }
    _selectedGameMode = mode;
    _generateTrackWorld(_selectedTrack, _seed);
    _resetSkierKinematics();
    notifyListeners();
  }

  void startRun({SkiTrackId? track, SkiGameMode? mode, int? seed}) {
    if (track != null) {
      _selectedTrack = track;
    }
    if (mode != null) {
      _selectedGameMode = mode;
    }
    if (seed != null) {
      _seed = seed;
    }
    _generateTrackWorld(_selectedTrack, _seed);
    _resetSkierKinematics();
    isInMenu = false;
    isHighscoresOpen = false;
    isTurntableGalleryOpen = false;
    isTrackFinished = false;
    isPaused = false;
    notifyListeners();
  }

  void restartCurrentTrack() {
    startRun(track: _selectedTrack, mode: _selectedGameMode, seed: _seed);
  }

  void startNextTrack() {
    startRun(
      track: _selectedTrack.nextTrack,
      mode: _selectedGameMode,
      seed: _seed + 1,
    );
  }

  void returnToMainMenu() {
    isInMenu = true;
    isTrackFinished = false;
    isHighscoresOpen = false;
    isTurntableGalleryOpen = false;
    isPaused = false;
    _manualTilt = 0.0;
    _manualTiltActive = false;
    _generateTrackWorld(_selectedTrack, _seed);
    _resetSkierKinematics();
    notifyListeners();
  }

  void openHighscores({SkiTrackId? track}) {
    _highscoresFilterTrack = track ?? _selectedTrack;
    isHighscoresOpen = true;
    isTurntableGalleryOpen = false;
    if (!isInMenu && !isTrackFinished) {
      isPaused = true;
    }
    notifyListeners();
  }

  void closeHighscores() {
    isHighscoresOpen = false;
    notifyListeners();
  }

  void setHighscoresFilterTrack(SkiTrackId? track) {
    _highscoresFilterTrack = track;
    notifyListeners();
  }

  void openTurntableGallery() {
    isTurntableGalleryOpen = true;
    isHighscoresOpen = false;
    if (!isInMenu && !isTrackFinished) {
      isPaused = true;
    }
    notifyListeners();
  }

  void closeTurntableGallery() {
    isTurntableGalleryOpen = false;
    notifyListeners();
  }

  void togglePause() {
    if (isInMenu || isTrackFinished) return;
    isPaused = !isPaused;
    notifyListeners();
  }

  void setPaused(bool value) {
    if (isPaused == value) return;
    isPaused = value;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Hardware Accelerometer & Touch/Keyboard Steering
  // ---------------------------------------------------------------------------

  /// Updates the hardware accelerometer vector `(ax, ay, az)` in m/s² (Portrait).
  /// On Android (`Sensor.TYPE_ACCELEROMETER`) and normalized iOS (`CMMotionManager`),
  /// tilting the top of the phone right yields `ax < 0`, producing positive `effectiveTiltX`.
  void updateHardwareSensor(double ax, double ay, double az) {
    rawSensorAx = ax;
    rawSensorAy = ay;
    rawSensorAz = az;
    hasHardwareSensor = true;

    final double calibratedDelta = -(ax - calibrationOffsetAx);
    double rawTilt = (calibratedDelta / 5.4).clamp(-1.0, 1.0);
    if (rawTilt.abs() < 0.035) {
      rawTilt = 0.0;
    }

    _rawTargetHardwareTilt = rawTilt;
    // Exponential low-pass filter smoothing hand jitter while staying crisp
    _smoothedHardwareTilt += (rawTilt - _smoothedHardwareTilt) * 0.48;
    if (_smoothedHardwareTilt.abs() < 0.008 && rawTilt == 0.0) {
      _smoothedHardwareTilt = 0.0;
    }

    if (isTurntableGalleryOpen) {
      turntableAngleDegrees =
          (turntableAngleDegrees + _smoothedHardwareTilt * 6.0 + 360.0) %
              360.0;
    }
    notifyListeners();
  }

  void calibrateAccelerometer() {
    calibrationOffsetAx = rawSensorAx;
    _rawTargetHardwareTilt = 0.0;
    _smoothedHardwareTilt = 0.0;
    notifyListeners();
  }

  void setManualTilt(double tilt) {
    _manualTilt = tilt.clamp(-1.0, 1.0);
    _manualTiltActive = _manualTilt.abs() > 0.001;
    if (isTurntableGalleryOpen && _manualTiltActive) {
      turntableAngleDegrees =
          (turntableAngleDegrees + _manualTilt * 9.0 + 360.0) % 360.0;
    }
    notifyListeners();
  }

  void clearManualTilt() {
    if (!_manualTiltActive && _manualTilt == 0.0) return;
    _manualTilt = 0.0;
    _manualTiltActive = false;
    notifyListeners();
  }

  void rotateTurntableBy(double deltaDegrees) {
    turntableAngleDegrees =
        ((turntableAngleDegrees + deltaDegrees) % 360.0 + 360.0) % 360.0;
    notifyListeners();
  }

  void setTurntableAngle(double degrees) {
    turntableAngleDegrees = ((degrees % 360.0) + 360.0) % 360.0;
    notifyListeners();
  }

  /// Rear Cycles turntable sprite index (`09..15`, centered on `12 = 180° Dos`)
  /// or full `00..23` spin frame when executing `saut360` in midair!
  int get activeSkierTurntableFrameIndex {
    if (isAirborne && currentAerialTrick == SkiAerialTrickKind.saut360) {
      final double spinDegrees =
          180.0 + (trickSpinAngle * 180.0 / math.pi);
      return VivienneTurntableSpec.frameIndexForAngle(spinDegrees);
    }
    final double visualCarve =
        (playerRollRadians / 0.42).clamp(-1.0, 1.0);
    return VivienneTurntableSpec.rearCarvingFrameIndex(visualCarve);
  }

  // ---------------------------------------------------------------------------
  // Deterministic 3D Slope Curve & Elevation Profile
  // ---------------------------------------------------------------------------

  /// Smooth horizontal S-curve of the piste center at world distance `z` (meters).
  double trackCenterOffsetX(double z) {
    final double length = _selectedTrack.lengthMeters;
    // Smoothly taper curvature near the Start Arch and Finish Chalet
    final double startFade = (z / 48.0).clamp(0.0, 1.0);
    final double endFade = ((length - z) / 68.0).clamp(0.0, 1.0);
    final double envelope = startFade * endFade;

    final double amp = _selectedTrack.curveAmplitudeMeters;
    final double seedPhase = (_seed % 97) * 0.065;
    final double primary = math.sin(z * 0.014 + seedPhase) * amp;
    final double secondary =
        math.sin(z * 0.031 + seedPhase * 1.7) * (amp * 0.42);
    return (primary + secondary) * envelope;
  }

  /// Continuous vertical downhill profile + dramatic multi-section alpine relief at `z`.
  double trackElevationY(double z) {
    final double slopeRad = _selectedTrack.slopeDegrees * math.pi / 180.0;
    final double baseDrop = -z * math.tan(slopeRad);
    return baseDrop + relativeReliefAtZ(z);
  }

  /// Dramatic multi-section alpine relief (`v1.4.0`):
  /// Alternates progressive convex replats/rollers ("Replats & Bosses de Relief")
  /// that visually climb above `horizonY` to mask background mountains/sky,
  /// followed by steep plunging walls ("Murs de Descente Plongeants")!
  double relativeReliefAtZ(double z) {
    final double startFade = (z / 30.0).clamp(0.0, 1.0);
    final double endFade =
        ((_selectedTrack.lengthMeters - z) / 50.0).clamp(0.0, 1.0);
    final double reliefAmp =
        10.2 + (_selectedTrack.slopeDegrees / 45.0) * 6.4;
    final double u = z * 0.033 + 0.35;
    final double asymmetricWave = 0.84 * math.sin(u) -
        0.24 * math.sin(2.0 * u) +
        0.08 * math.cos(3.0 * u + 0.5);
    return asymmetricWave * reliefAmp * startFade * endFade;
  }

  /// Local derivative `d(relativeReliefAtZ)/dz`:
  /// - `> 0.0`: rising replat / convex roller approaching a crest
  /// - `< 0.0`: plunging downhill wall right after a crest
  double localReliefGradientAt(double z) {
    const double eps = 0.75;
    return (relativeReliefAtZ(z + eps) - relativeReliefAtZ(z - eps)) /
        (2.0 * eps);
  }

  /// Effective local downhill gradient `-d(trackElevationY)/dz`:
  /// - Small values (`< 0.38`) = flat / replat compression section before a convex crest
  /// - High values (`> 0.88`) = steep plunging wall ("mur de descente")
  double localSlopeGradientAt(double z) {
    final double slopeRad = _selectedTrack.slopeDegrees * math.pi / 180.0;
    return math.tan(slopeRad) - localReliefGradientAt(z);
  }

  /// Smooth `C¹` 3D mogul elevation integrated directly into the snow slope mesh (`v1.4.0`).
  double mogulElevationAt(double worldX, double worldZ) {
    double totalY = 0.0;
    for (int i = 0; i < moguls.length; i++) {
      final SkiMogul3D m = moguls[i];
      final double dz = worldZ - m.z;
      if (dz.abs() >= m.radiusZ) continue;
      final double dx = worldX - m.x;
      if (dx.abs() >= m.radiusX) continue;
      final double nx = dx / m.radiusX;
      final double nz = dz / m.radiusZ;
      final double u2 = nx * nx + nz * nz;
      if (u2 < 1.0) {
        // C¹-smooth cosine-squared bell (`cos²(π/2 * r)`) with zero rim derivative
        final double c = math.cos(math.sqrt(u2) * math.pi * 0.5);
        final double dome = m.heightMeters * c * c;
        if (dome > totalY) {
          totalY = dome;
        }
      }
    }
    return totalY;
  }

  /// Inclined 3D jump ramp deck height above snow at `(worldX, worldZ)` (`0.0` outside ramps).
  double rampDeckElevationAt(double worldX, double worldZ) {
    double maxDeckY = 0.0;
    for (int i = 0; i < jumpRamps.length; i++) {
      final SkiJumpRamp3D ramp = jumpRamps[i];
      final double zStart = ramp.z - ramp.length * 0.5;
      final double zEnd = ramp.z + ramp.length * 0.5;
      if (worldZ < zStart || worldZ > zEnd) continue;
      if ((worldX - ramp.x).abs() > ramp.width * 0.68) continue;
      final double t = ((worldZ - zStart) / ramp.length).clamp(0.0, 1.0);
      final double deckY = t * ramp.heightMeters;
      if (deckY > maxDeckY) {
        maxDeckY = deckY;
      }
    }
    return maxDeckY;
  }

  /// Active local ground/deck height above the macro piste relief at `(worldX, worldZ)` (`v1.5.0`).
  double groundSurfaceHeightAt(double worldX, double worldZ) {
    return math.max(
      mogulElevationAt(worldX, worldZ),
      rampDeckElevationAt(worldX, worldZ),
    );
  }

  /// Combined 3D snow surface height (`macro relief + integrated 3D moguls`) at `(worldX, worldZ)`.
  double snowSurfaceHeightAt(double worldX, double worldZ) {
    return relativeReliefAtZ(worldZ) + mogulElevationAt(worldX, worldZ);
  }

  // ---------------------------------------------------------------------------
  // Real-Time Physics Simulation Step (60–120 Hz)
  // ---------------------------------------------------------------------------

  void update(double dt) {
    final double clampedDt = dt.clamp(0.0, 0.05);
    if (clampedDt <= 0.0) return;

    ambientTime += clampedDt;
    if (hasHardwareSensor) {
      _smoothedHardwareTilt += (_rawTargetHardwareTilt - _smoothedHardwareTilt) *
          (1.0 - math.exp(-clampedDt * 14.0));
    }

    if (isTurntableGalleryOpen) {
      if (effectiveTiltX.abs() > 0.01) {
        turntableAngleDegrees =
            (turntableAngleDegrees + effectiveTiltX * 140.0 * clampedDt + 360.0) %
                360.0;
      }
      _updateSnowParticles(clampedDt, baseVz: 8.0);
      notifyListeners();
      return;
    }

    if (isInMenu || isPaused || isTrackFinished) {
      scarfWavePhase = (scarfWavePhase + clampedDt * 5.2) % (math.pi * 200);
      _updateSnowParticles(clampedDt, baseVz: isInMenu ? 12.0 : 3.0);
      _updateCallouts(clampedDt);
      notifyListeners();
      return;
    }

    elapsedSeconds += clampedDt;
    if (_mogulSquashTimer > 0) {
      _mogulSquashTimer = math.max(0.0, _mogulSquashTimer - clampedDt);
    }
    if (_launchStretchTimer > 0) {
      _launchStretchTimer = math.max(0.0, _launchStretchTimer - clampedDt);
    }
    if (_landingSquashTimer > 0) {
      _landingSquashTimer = math.max(0.0, _landingSquashTimer - clampedDt);
    }
    if (_stumbleTimer > 0) {
      _stumbleTimer = math.max(0.0, _stumbleTimer - clampedDt);
    }
    if (_stumbleCooldown > 0) {
      _stumbleCooldown = math.max(0.0, _stumbleCooldown - clampedDt);
    }
    if (_speedBoostTimer > 0) {
      _speedBoostTimer = math.max(0.0, _speedBoostTimer - clampedDt);
    }
    if (snowballCrashTimer > 0) {
      final double prevCrash = snowballCrashTimer;
      snowballCrashTimer = math.max(0.0, snowballCrashTimer - clampedDt);
      // 3 full 360° revolutions over `snowballCrashDuration` (1.15s)
      snowballRotationRadians +=
          (math.pi * 6.0 / snowballCrashDuration) * clampedDt;
      if (snowParticles.length < 145) {
        snowParticles.add(
          SkiSnowParticle3D(
            x: playerWorldX + (math.sin(snowballRotationRadians * 2.3) * 0.75),
            y: 0.45 + (snowballCrashProgress * 0.35),
            z: playerZ - 0.5,
            vx: math.cos(snowballRotationRadians * 1.9) * 3.6,
            vy: 2.8,
            vz: 1.5,
            size: 4.8,
            life: 0.44,
            maxLife: 0.44,
            color: Colors.white,
            isPowderSpray: true,
          ),
        );
      }
      if (prevCrash > 0.0 && snowballCrashTimer <= 0.0) {
        _spawnPowderBurst(count: 14, upwardVy: 5.0);
      }
    }

    // 1. High-Gradient Downhill Speed Physics (`24°`, `34°`, `45°` + Steep Walls & Replats!)
    final double tiltAbs = effectiveTiltX.abs();
    final double editionMaxKmh =
        _selectedTrack.maxSpeedKmh * _selectedEdition.glideBonusMultiplier;
    final double carveDragFactor = 1.0 - tiltAbs * 0.14;
    final double offPisteRatio =
        (playerLateralOffset.abs() / _selectedTrack.trackHalfWidthMeters);
    final double powderDragFactor = offPisteRatio > 0.96 ? 0.80 : 1.0;
    final double crashDragFactor = snowballCrashTimer > 0 ? 0.78 : 1.0;
    final double boostBonusKmh = _speedBoostTimer > 0 ? 18.0 : 0.0;

    // Authentic relief speed feel: strong acceleration on plunging walls (`reliefGrad < 0`)
    // and subtle compression drag on rising replats before crests (`reliefGrad > 0`)!
    final double reliefGrad = localReliefGradientAt(playerZ);
    final double steepWallAccelKmh = math.max(0.0, -reliefGrad) * 28.0;
    final double replatCompressionKmh = math.max(0.0, reliefGrad) * 14.0;

    final double targetKmh = ((_selectedTrack.baseSpeedKmh +
                    (_selectedTrack.maxSpeedKmh - _selectedTrack.baseSpeedKmh) *
                        0.76 +
                    steepWallAccelKmh -
                    replatCompressionKmh) *
                _selectedEdition.glideBonusMultiplier *
                carveDragFactor *
                powderDragFactor *
                crashDragFactor +
            boostBonusKmh)
        .clamp(_selectedTrack.baseSpeedKmh * 0.62, editionMaxKmh + 22.0);

    final double accelRate = speedKmh < targetKmh ? 2.6 : 3.1;
    speedKmh +=
        (targetKmh - speedKmh) * (1.0 - math.exp(-clampedDt * accelRate));

    final double vz = speedKmh / 3.6;
    final double prevZ = playerZ;
    playerZ += vz * clampedDt;

    // 2. Lateral Carving Kinematics
    final double prevVx = playerVx;
    final double targetVx = effectiveTiltX *
        (15.0 + vz * 0.38) *
        _selectedEdition.carvingMultiplier;
    final double lateralControlFactor = playerY > 0.25 ? 0.55 : 1.0;
    playerVx += (targetVx - playerVx) *
        (1.0 - math.exp(-clampedDt * 12.0 * lateralControlFactor));

    final double maxLat = _selectedTrack.trackHalfWidthMeters * 1.38;
    playerLateralOffset =
        (playerLateralOffset + playerVx * clampedDt).clamp(-maxLat, maxLat);

    final double targetRoll = (effectiveTiltX * 0.42).clamp(-0.46, 0.46);
    playerRollRadians +=
        (targetRoll - playerRollRadians) * (1.0 - math.exp(-clampedDt * 12.0));

    // Secondary pendulum dynamics for the Mini Speedy LV bag & Cashmere Scarf
    final double lateralAccel = (playerVx - prevVx) / clampedDt;
    final double pendulumTorque =
        -lateralAccel * 0.018 - 28.0 * speedyBagSwingRadians - 5.2 * _speedyBagAngularVel;
    _speedyBagAngularVel += pendulumTorque * clampedDt;
    speedyBagSwingRadians =
        (speedyBagSwingRadians + _speedyBagAngularVel * clampedDt)
            .clamp(-0.62, 0.62);
    scarfWavePhase =
        (scarfWavePhase + clampedDt * (6.0 + vz * 0.32)) % (math.pi * 200);

    // 3. Moguls (Bosses 3D) Interaction
    final double wx = playerWorldX;
    double groundSurfaceY = 0.0;

    for (int i = 0; i < moguls.length; i++) {
      final SkiMogul3D m = moguls[i];
      if ((m.z - playerZ).abs() > m.radiusZ + 2.5) continue;

      final double nx = (wx - m.x) / m.radiusX;
      final double nz = (playerZ - m.z) / m.radiusZ;
      final double u2 = nx * nx + nz * nz;
      if (u2 < 1.0) {
        final double c = math.cos(math.sqrt(u2) * math.pi * 0.5);
        final double domeY = m.heightMeters * c * c;
        groundSurfaceY = math.max(groundSurfaceY, domeY);

        if (playerY <= domeY + 0.35) {
          _mogulSquashTimer = 0.26;
          if (!m.absorbed) {
            moguls[i] = m.copyWith(absorbed: true);
            mogulsAbsorbed++;
            jumpAndMogulPoints += 85;
            _addCallout('BOSSE SQUASH +85', const Color(0xFFFFD54F));
            _spawnPowderBurst(count: 6, upwardVy: 3.4);
            onHapticEvent?.call(SkiHapticEvent.mogulBump);
          }
          // High-speed crest pop & bonus aerial trick when clear of upcoming jump ramps!
          if (playerZ >= m.z &&
              playerVy <= 0.5 &&
              speedKmh > _selectedTrack.baseSpeedKmh * 1.05) {
            final bool rampCloseAhead = jumpRamps.any(
              (SkiJumpRamp3D r) => r.z > playerZ && (r.z - playerZ) < 32.0,
            );
            if (!rampCloseAhead &&
                speedKmh > _selectedTrack.baseSpeedKmh * 1.24) {
              final SkiAerialTrickKind mogulTrick = mogulsAbsorbed.isOdd
                  ? SkiAerialTrickKind.saut360
                  : SkiAerialTrickKind.sautPerilleux;
              _launchAerialStunt(
                launchVy: 9.6 * _selectedEdition.jumpBoostMultiplier,
                initialHeight: math.max(playerY, domeY + 0.18),
                trick: mogulTrick,
              );
            } else {
              playerVy = 4.2 * _selectedEdition.jumpBoostMultiplier;
            }
          }
        }
      }
    }

    // 4. Ski Jump Ramps (Tremplins 3D) Interaction (`v1.5.0`: Vivienne always rides ON TOP of the deck)
    for (int i = 0; i < jumpRamps.length; i++) {
      final SkiJumpRamp3D ramp = jumpRamps[i];
      final double zStart = ramp.z - ramp.length * 0.5;
      final double zEnd = ramp.z + ramp.length * 0.5;
      if (playerZ < zStart - 1.0 || prevZ > zEnd + 1.5) continue;

      final bool alignedX = (wx - ramp.x).abs() <= ramp.width * 0.68;
      if (!alignedX) continue;

      if (playerZ >= zStart && playerZ <= zEnd) {
        final double t = ((playerZ - zStart) / ramp.length).clamp(0.0, 1.0);
        final double deckY = t * ramp.heightMeters;
        groundSurfaceY = math.max(groundSurfaceY, deckY);
        playerY = math.max(playerY, deckY);
        if (playerY <= deckY + 0.65) {
          _launchStretchTimer = 0.22;
        }
      }

      // Trigger Big Air launch near the lip or if swept across zEnd
      final bool reachedLip =
          (playerZ >= zStart + ramp.length * 0.72 && playerZ <= zEnd + 2.2) ||
              (prevZ <= zEnd && playerZ >= zEnd);
      if (reachedLip && !ramp.triggered && playerY <= ramp.heightMeters + 1.2) {
        jumpRamps[i] = ramp.copyWith(triggered: true);
        _triggerJumpLaunch(ramp);
      }
    }

    // 5. Vertical Airborne Kinematics (Gravity, Saut 360° / Saut Périlleux, Landing Impact)
    const double skiGravity = 16.8;
    if (playerY > groundSurfaceY || playerVy > 0.0) {
      airtimeSeconds += clampedDt;
      totalAirtimeSeconds += clampedDt;
      playerVy -= skiGravity * clampedDt;
      playerY += playerVy * clampedDt;

      if (playerY > currentJumpHeightMeters) {
        currentJumpHeightMeters = playerY;
      }
      if (playerY > maxJumpHeightMeters) {
        maxJumpHeightMeters = playerY;
      }

      // Smooth 0 -> 2π progression for `saut360` and `sautPerilleux`
      final double flightSpan = math.max(0.55, _expectedFlightDuration * 0.94);
      trickProgress = (airtimeSeconds / flightSpan).clamp(0.0, 1.0);
      final double smoothT = 0.55 * trickProgress +
          0.45 * (0.5 - 0.5 * math.cos(trickProgress * math.pi));
      if (currentAerialTrick == SkiAerialTrickKind.saut360) {
        trickSpinAngle = (smoothT * 2.0 * math.pi).clamp(0.0, 2.0 * math.pi);
        trickFlipAngle = 0.0;
      } else if (currentAerialTrick == SkiAerialTrickKind.sautPerilleux) {
        trickFlipAngle = (smoothT * 2.0 * math.pi).clamp(0.0, 2.0 * math.pi);
        trickSpinAngle = 0.0;
      } else {
        trickSpinAngle = 0.0;
        trickFlipAngle = 0.0;
      }

      if (playerY <= groundSurfaceY && playerVy <= 0.0) {
        playerY = groundSurfaceY;
        if (currentJumpHeightMeters >= 0.75) {
          _landingSquashTimer = 0.28;
          _spawnPowderBurst(count: 16, upwardVy: 5.2);
          onHapticEvent?.call(SkiHapticEvent.landingImpact);
        }
        playerVy = 0.0;
        airtimeSeconds = 0.0;
        currentJumpHeightMeters = 0.0;
        currentAerialTrick = SkiAerialTrickKind.none;
        trickSpinAngle = 0.0;
        trickFlipAngle = 0.0;
        trickProgress = 0.0;
      }
    } else {
      playerY = groundSurfaceY;
      playerVy = 0.0;
      currentAerialTrick = SkiAerialTrickKind.none;
      trickSpinAngle = 0.0;
      trickFlipAngle = 0.0;
      trickProgress = 0.0;
    }

    // 6. Slalom Gates Validation & Articulated Flex-Pole Rebound (`v1.4.0`)
    for (int i = 0; i < slalomGates.length; i++) {
      final SkiSlalomGate3D gate = slalomGates[i];
      if (gate.poleFlex > 0.0) {
        final double nextFlex = math.max(0.0, gate.poleFlex - clampedDt * 2.2);
        slalomGates[i] = gate.copyWith(poleFlex: nextFlex);
      }
      if (gate.passed || gate.missed) continue;
      if (prevZ < gate.z && playerZ >= gate.z) {
        if ((wx - gate.centerX).abs() <= gate.halfWidth + 0.50) {
          slalomGates[i] = gate.copyWith(passed: true, poleFlex: 1.0);
          slalomPassed++;
          slalomCombo++;
          if (slalomCombo > maxSlalomCombo) {
            maxSlalomCombo = slalomCombo;
          }
          final int baseGatePts = isSlalomMode ? 140 : 100;
          final int comboBonusPts = isSlalomMode ? 35 : 25;
          final int gatePts = baseGatePts + slalomCombo * comboBonusPts;
          slalomPoints += gatePts;
          _speedBoostTimer = isSlalomMode ? 1.05 : 0.9;
          final String sideTag = gate.isLeftGate ? 'GAUCHE' : 'DROITE';
          _addCallout(
            'PORTE ${gate.gateNumber} ($sideTag) ×$slalomCombo +$gatePts',
            gate.isLeftGate
                ? const Color(0xFFFFD54F)
                : const Color(0xFF40C4FF),
          );
          onHapticEvent?.call(SkiHapticEvent.slalomGate);
        } else {
          slalomGates[i] = gate.copyWith(missed: true);
          slalomCombo = 0;
          if (isSlalomMode) {
            _addCallout('PORTE MANQUÉE !', const Color(0xFFFF5252));
          }
        }
      }
    }

    // 7. Blossom 3D Flowers Collection (Ground + Midair Jump Arcs)
    final double magnetR = _selectedEdition.blossomMagnetMeters;
    final double magnetR2 = magnetR * magnetR;
    for (int i = 0; i < blossoms.length; i++) {
      final SkiBlossomCollectible3D b = blossoms[i];
      if (b.collected) continue;
      if ((b.z - playerZ).abs() > magnetR + 1.8) continue;

      final double dx = wx - b.x;
      final double dy = (playerY + 0.9) - (b.y + 0.6);
      final double dz = (playerZ - b.z) * 0.65;
      if (dx * dx + dy * dy * 0.65 + dz * dz <= magnetR2) {
        blossoms[i] = b.copyWith(collected: true);
        blossomsCollected++;
        blossomPoints += b.points;
        if (b.isStarGold) {
          _addCallout('STAR BLOSSOM OR +${b.points}', const Color(0xFFFFD700));
        }
        onHapticEvent?.call(SkiHapticEvent.blossomPickup);
      }
    }

    // 8. Full 3D Pine Tree Snowball Crash (`v1.5.0`):
    //    - Case A: Orange Piste Safety Pad in front of on-piste pine trees (`prop.isOnPiste`)
    //    - Case B: Conical foliage branches (low, mid, and high)
    //    - Case C: Upper crown / treetop (`0.82 * treeHeight .. treeHeight + 0.35`) in midair!
    if (_stumbleCooldown <= 0.0 && snowballCrashTimer <= 0.0) {
      for (int i = 0; i < worldProps.length; i++) {
        final SkiWorldProp3D prop = worldProps[i];
        if (prop.kind != SkiPropKind.alpinePineTree &&
            prop.kind != SkiPropKind.giantSnowPine) {
          continue;
        }
        final PineCollisionZone? hitZone = checkPineTreeCollision(
          prop,
          wx: wx,
          y: playerY,
          prevZ: prevZ,
          currZ: playerZ,
        );
        if (hitZone != null) {
          lastPineCollisionZone = hitZone;
          if (playerVy > 1.2) {
            playerVy = 1.2;
          }
          _triggerSnowballCrash(dx: wx - prop.x, maxLat: maxLat);
          break;
        }
      }
    }

    // 9. Determine Active VivienneSkiAnimState & Interpolate Squash/Stretch
    _updateAnimationState(clampedDt);

    // 10. Record Dual Ski Tracks & Spawn Carving Spray
    _recordSkiTrailAndCarveSpray(clampedDt, vz);
    _updateSnowParticles(clampedDt, baseVz: vz);
    _updateCallouts(clampedDt);

    // 11. Finish Arch & Alpine Chalet Arrival
    if (playerZ >= _selectedTrack.lengthMeters) {
      playerZ = _selectedTrack.lengthMeters;
      _completeRunAtChalet();
    }

    notifyListeners();
  }

  /// Evaluates 3D collision against a pine tree (`alpinePineTree` or `giantSnowPine`):
  /// - [PineCollisionZone.orangePad]: Orange crash mattress in front of on-piste pine trees (`prop.isOnPiste`)
  /// - [PineCollisionZone.branch]: Conical foliage branches (`0 .. 0.82 * treeHeight`)
  /// - [PineCollisionZone.treetop]: Upper crown / apex of the pine tree (`0.82 * treeHeight .. treeHeight + 0.35`)
  PineCollisionZone? checkPineTreeCollision(
    SkiWorldProp3D prop, {
    required double wx,
    required double y,
    required double prevZ,
    required double currZ,
  }) {
    if (prop.kind != SkiPropKind.alpinePineTree &&
        prop.kind != SkiPropKind.giantSnowPine) {
      return null;
    }

    final double zMin = math.min(prevZ, currZ);
    final double zMax = math.max(prevZ, currZ);
    final double maxZReach = 2.60 * prop.scale;
    if (zMax < prop.z - maxZReach || zMin > prop.z + maxZReach) {
      return null;
    }

    final double treeHeight =
        (prop.kind == SkiPropKind.giantSnowPine ? 7.4 : 5.8) * prop.scale;
    if (y > treeHeight + 0.35) {
      return null;
    }

    final double dxAbs = (wx - prop.x).abs();

    // Case A — Contact with the Orange Safety Pad in front of an on-piste pine tree
    if (prop.isOnPiste &&
        y <= 2.10 * prop.scale &&
        zMax >= prop.z - 2.45 * prop.scale &&
        zMin <= prop.z + 0.90 * prop.scale &&
        dxAbs < 1.72 * prop.scale) {
      return PineCollisionZone.orangePad;
    }

    // Case B — Contact with low, mid, or high conical branches
    if (y <= treeHeight * 0.82 &&
        zMax >= prop.z - 1.85 * prop.scale &&
        zMin <= prop.z + 1.85 * prop.scale) {
      final double heightFrac = (y / treeHeight).clamp(0.0, 0.82);
      final double branchRadius = (2.15 - 0.75 * heightFrac) * prop.scale;
      if (dxAbs < branchRadius) {
        return PineCollisionZone.branch;
      }
    }

    // Case C — Contact with the crown / treetop while airborne
    if (y > treeHeight * 0.82 &&
        y <= treeHeight + 0.35 &&
        zMax >= prop.z - 1.65 * prop.scale &&
        zMin <= prop.z + 1.65 * prop.scale &&
        dxAbs < 1.05 * prop.scale) {
      return PineCollisionZone.treetop;
    }

    return null;
  }

  void _triggerSnowballCrash({required double dx, required double maxLat}) {
    snowballCrashTimer = snowballCrashDuration;
    snowballRotationRadians = 0.0;
    _stumbleCooldown = 1.65;
    animState = VivienneSkiAnimState.snowballCrash;
    slalomCombo = 0;
    speedKmh =
        math.max(_selectedTrack.baseSpeedKmh * 0.68, speedKmh * 0.74);
    final double pushDir = dx >= 0 ? 1.0 : -1.0;
    playerVx = pushDir * 7.2;
    playerLateralOffset =
        (playerLateralOffset + pushDir * 0.85).clamp(-maxLat, maxLat);
    _spawnPowderBurst(count: 26, upwardVy: 6.5, includePineNeedles: true);
    _addCallout('BOUM ! BOULE DE NEIGE !', const Color(0xFFFF5252));
    onHapticEvent?.call(SkiHapticEvent.obstacleBounce);
  }

  /// Convenience helper to trigger the 3D Cartoon Snowball Crash in automated tests & screenshots.
  void triggerSnowballCrashForTest({double progress = 0.35}) {
    final double clamped = progress.clamp(0.0, 0.92);
    snowballCrashTimer = snowballCrashDuration * (1.0 - clamped);
    snowballRotationRadians = clamped * math.pi * 6.0;
    _stumbleCooldown = 1.65;
    animState = VivienneSkiAnimState.snowballCrash;
    _spawnPowderBurst(count: 26, upwardVy: 6.5, includePineNeedles: true);
    _addCallout('BOUM ! BOULE DE NEIGE !', const Color(0xFFFF5252));
    notifyListeners();
  }

  void _launchAerialStunt({
    required double launchVy,
    required double initialHeight,
    required SkiAerialTrickKind trick,
  }) {
    const double skiGravity = 16.8;
    playerVy = launchVy;
    playerY = math.max(playerY, initialHeight);
    airtimeSeconds = 0.0;
    currentJumpHeightMeters = playerY;
    if (playerY > maxJumpHeightMeters) {
      maxJumpHeightMeters = playerY;
    }

    // Exact ballistic flight duration: y0 + vy * t - 0.5 * g * t^2 = 0
    final double disc = launchVy * launchVy + 2.0 * skiGravity * playerY;
    _expectedFlightDuration =
        ((launchVy + math.sqrt(math.max(0.0, disc))) / skiGravity)
            .clamp(0.75, 2.40);

    currentAerialTrick = trick;
    trickSpinAngle = 0.0;
    trickFlipAngle = 0.0;
    trickProgress = 0.0;
    _launchStretchTimer = 0.20;
    _speedBoostTimer = 1.4;
    jumpsCompleted++;

    final int bonus = trick.bonusPoints;
    if (bonus > 0) {
      jumpAndMogulPoints += bonus;
      final Color badgeCol = trick == SkiAerialTrickKind.saut360
          ? const Color(0xFFFFD700)
          : const Color(0xFFFF4081);
      _addCallout(
        '${trick.title} +$bonus',
        badgeCol,
        duration: 1.40,
      );
    }
    _spawnPowderBurst(count: 14, upwardVy: 6.0);
    onHapticEvent?.call(SkiHapticEvent.rampLaunch);
  }

  void _triggerJumpLaunch(SkiJumpRamp3D ramp) {
    final double speedRatio =
        (speedKmh / _selectedTrack.maxSpeedKmh).clamp(0.75, 1.25);
    final double jumpVerticalVelocity = ramp.boostVy *
        _selectedEdition.jumpBoostMultiplier *
        (0.90 + 0.16 * speedRatio);

    final SkiAerialTrickKind bonusTrick = _rampTrickCounter.isEven
        ? SkiAerialTrickKind.saut360
        : SkiAerialTrickKind.sautPerilleux;
    _rampTrickCounter++;

    _launchAerialStunt(
      launchVy: jumpVerticalVelocity,
      initialHeight: ramp.heightMeters + 0.28,
      trick: bonusTrick,
    );
  }

  /// Deterministic helper to position Vivienne midair in a `saut360` or `sautPerilleux`
  /// at a specific normalized `progress` in `[0.0, 1.0]` for tests and Store screenshots.
  void triggerBonusJumpForTest({
    required SkiAerialTrickKind trick,
    double progress = 0.50,
    double apexHeightMeters = 3.2,
  }) {
    final double p = progress.clamp(0.05, 0.92);
    _expectedFlightDuration = 1.28;
    final double flightSpan = _expectedFlightDuration * 0.94;
    airtimeSeconds = p * flightSpan;
    trickProgress = p;
    currentAerialTrick = trick;
    final double baseGround = playerGroundY;
    playerY = baseGround + 0.45 + math.sin(p * math.pi) * apexHeightMeters;
    playerVy = math.cos(p * math.pi) * 11.8;
    currentJumpHeightMeters = math.max(currentJumpHeightMeters, playerY);
    maxJumpHeightMeters = math.max(maxJumpHeightMeters, playerY);
    _launchStretchTimer = p < 0.14 ? 0.15 : 0.0;
    animState = p < 0.14
        ? VivienneSkiAnimState.rampLaunchStretch
        : VivienneSkiAnimState.airborneCelebration;

    final double smoothT =
        0.55 * p + 0.45 * (0.5 - 0.5 * math.cos(p * math.pi));
    if (trick == SkiAerialTrickKind.saut360) {
      trickSpinAngle = smoothT * 2.0 * math.pi;
      trickFlipAngle = 0.0;
    } else if (trick == SkiAerialTrickKind.sautPerilleux) {
      trickFlipAngle = smoothT * 2.0 * math.pi;
      trickSpinAngle = 0.0;
    }
    jumpsCompleted++;
    jumpAndMogulPoints += trick.bonusPoints;
    callouts
      ..clear()
      ..add(
        SkiFloatingCallout(
          text: '${trick.title} +${trick.bonusPoints}',
          color: trick == SkiAerialTrickKind.saut360
              ? const Color(0xFFFFD700)
              : const Color(0xFFFF4081),
          life: 1.15,
          maxLife: 1.40,
        ),
      );
    _spawnPowderBurst(
      count: 10,
      upwardVy: 4.2,
      spawnY: 0.22,
      spawnZ: playerZ - p * 6.5,
    );
    notifyListeners();
  }

  void _updateAnimationState(double dt) {
    final double clearanceY = playerY - playerGroundY;
    if (snowballCrashTimer > 0.0) {
      animState = VivienneSkiAnimState.snowballCrash;
    } else if (_stumbleTimer > 0.0) {
      animState = VivienneSkiAnimState.obstacleStumble;
    } else if (clearanceY > 0.42 || playerVy > 1.8) {
      if (_launchStretchTimer > 0.0 && playerVy > 0.0) {
        animState = VivienneSkiAnimState.rampLaunchStretch;
      } else {
        animState = VivienneSkiAnimState.airborneCelebration;
      }
    } else if (_landingSquashTimer > 0.0) {
      animState = VivienneSkiAnimState.landingImpact;
    } else if (_mogulSquashTimer > 0.0) {
      animState = VivienneSkiAnimState.mogulAbsorptionSquash;
    } else if (_launchStretchTimer > 0.0) {
      animState = VivienneSkiAnimState.rampLaunchStretch;
    } else if (effectiveTiltX < -0.14 || playerRollRadians < -0.09) {
      animState = VivienneSkiAnimState.carvingLeft;
    } else if (effectiveTiltX > 0.14 || playerRollRadians > 0.09) {
      animState = VivienneSkiAnimState.carvingRight;
    } else {
      animState = VivienneSkiAnimState.glidingRearNeutral;
    }

    final double lerpFactor = 1.0 - math.exp(-dt * 16.0);
    currentAnimScaleX +=
        (animState.scaleX - currentAnimScaleX) * lerpFactor;
    currentAnimScaleY +=
        (animState.scaleY - currentAnimScaleY) * lerpFactor;
    armRaiseProgress +=
        (animState.armRaiseFactor - armRaiseProgress) *
            (1.0 - math.exp(-dt * 12.0));
  }

  void _recordSkiTrailAndCarveSpray(double dt, double vz) {
    final bool skisOnSnow = (playerY - playerGroundY) <= 0.18;
    final double wx = playerWorldX;
    const double skiHalfStance = 0.42;

    if (skiTrailHistory.isEmpty ||
        (playerZ - skiTrailHistory.last.z) >= 1.6) {
      skiTrailHistory.add(
        SkiTrackRibbonPoint(
          z: playerZ,
          centerX: trackCenterOffsetX(playerZ),
          elevationY: trackElevationY(playerZ),
          halfWidth: _selectedTrack.trackHalfWidthMeters,
          leftSkiX: wx - skiHalfStance,
          rightSkiX: wx + skiHalfStance,
          hasSkiMarks: skisOnSnow,
          carveIntensity: effectiveTiltX.abs(),
        ),
      );
      if (skiTrailHistory.length > 48) {
        skiTrailHistory.removeAt(0);
      }
    }

    // Spawn side powder plume when carving strongly on snow
    if (skisOnSnow && effectiveTiltX.abs() > 0.25 && snowParticles.length < 115) {
      final double sideSign = effectiveTiltX > 0 ? -1.0 : 1.0;
      snowParticles.add(
        SkiSnowParticle3D(
          x: wx + sideSign * 0.55,
          y: 0.15,
          z: playerZ - 0.4,
          vx: sideSign * (2.2 + effectiveTiltX.abs() * 3.8),
          vy: 1.8 + effectiveTiltX.abs() * 2.4,
          vz: vz * 0.35,
          size: 3.4 + effectiveTiltX.abs() * 2.5,
          life: 0.42,
          maxLife: 0.42,
          color: _selectedTrack.snowBrightColor,
          isPowderSpray: true,
        ),
      );
    }
  }

  void _spawnPowderBurst({
    required int count,
    required double upwardVy,
    bool includePineNeedles = false,
    double? spawnY,
    double? spawnZ,
  }) {
    final double wx = playerWorldX;
    final double baseY = spawnY ?? math.min(0.42, math.max(0.18, playerY + 0.10));
    final double baseZ = spawnZ ?? playerZ;
    for (int i = 0; i < count && snowParticles.length < 165; i++) {
      final double angle = (i / count) * math.pi * 2.0;
      final bool isNeedle = includePineNeedles && (i % 3 == 1);
      snowParticles.add(
        SkiSnowParticle3D(
          x: wx + math.cos(angle) * 0.55,
          y: baseY,
          z: baseZ + math.sin(angle) * 0.55,
          vx: math.cos(angle) * (2.8 + (i % 3) * 1.25),
          vy: upwardVy * (0.65 + (i % 4) * 0.14),
          vz: math.sin(angle) * 2.2,
          size: isNeedle ? 3.8 : (4.4 + (i % 3) * 1.5),
          life: isNeedle ? 0.68 : 0.58,
          maxLife: isNeedle ? 0.68 : 0.58,
          color: isNeedle
              ? (i.isEven ? const Color(0xFF1B5E20) : const Color(0xFF2E7D32))
              : Colors.white,
          isPowderSpray: true,
        ),
      );
    }
  }

  void _initAmbientSnowflakes() {
    snowParticles.clear();
    final math.Random rng = math.Random(_seed ^ 0x5A17);
    for (int i = 0; i < 42; i++) {
      snowParticles.add(
        SkiSnowParticle3D(
          x: (rng.nextDouble() * 2.0 - 1.0) * 24.0,
          y: rng.nextDouble() * 14.0 + 0.5,
          z: rng.nextDouble() * 110.0,
          vx: (rng.nextDouble() - 0.5) * 1.6,
          vy: -1.8 - rng.nextDouble() * 1.8,
          vz: -2.0,
          size: 2.2 + rng.nextDouble() * 2.8,
          life: 10.0,
          maxLife: 10.0,
          color: Colors.white,
          isPowderSpray: false,
        ),
      );
    }
  }

  void _updateSnowParticles(double dt, {required double baseVz}) {
    final double centerRefX = trackCenterOffsetX(playerZ);
    for (int i = snowParticles.length - 1; i >= 0; i--) {
      final SkiSnowParticle3D p = snowParticles[i];
      if (p.isPowderSpray) {
        final double nextLife = p.life - dt;
        if (nextLife <= 0.0) {
          snowParticles.removeAt(i);
          continue;
        }
        snowParticles[i] = SkiSnowParticle3D(
          x: p.x + p.vx * dt,
          y: math.max(0.0, p.y + p.vy * dt),
          z: p.z + p.vz * dt,
          vx: p.vx * 0.95,
          vy: p.vy - 9.8 * dt,
          vz: p.vz,
          size: p.size,
          life: nextLife,
          maxLife: p.maxLife,
          color: p.color,
          isPowderSpray: true,
        );
      } else {
        double nx = p.x + (p.vx + math.sin(ambientTime * 1.7 + i) * 0.6) * dt;
        double ny = p.y + p.vy * dt;
        double nz = p.z + p.vz * dt;
        if (ny < 0.2 || nz < playerZ - 8.0 || nz > playerZ + 135.0) {
          nz = playerZ + 18.0 + ((i * 19.0) % 105.0);
          ny = 11.5 + (i % 5) * 1.4;
          nx = centerRefX + (((i * 37) % 48) - 24).toDouble();
        }
        snowParticles[i] = SkiSnowParticle3D(
          x: nx,
          y: ny,
          z: nz,
          vx: p.vx,
          vy: p.vy,
          vz: p.vz,
          size: p.size,
          life: p.life,
          maxLife: p.maxLife,
          color: p.color,
          isPowderSpray: false,
        );
      }
    }
  }

  void _addCallout(String text, Color color, {double duration = 1.05}) {
    callouts.add(
      SkiFloatingCallout(
        text: text,
        color: color,
        life: duration,
        maxLife: duration,
      ),
    );
    if (callouts.length > 4) {
      callouts.removeAt(0);
    }
  }

  void _updateCallouts(double dt) {
    for (int i = callouts.length - 1; i >= 0; i--) {
      final SkiFloatingCallout c = callouts[i];
      final double next = c.life - dt;
      if (next <= 0.0) {
        callouts.removeAt(i);
      } else {
        callouts[i] = SkiFloatingCallout(
          text: c.text,
          color: c.color,
          life: next,
          maxLife: c.maxLife,
        );
      }
    }
  }

  void _completeRunAtChalet() {
    if (isTrackFinished) return;
    isTrackFinished = true;
    animState = VivienneSkiAnimState.airborneCelebration;
    armRaiseProgress = 1.0;

    final double timeSaved =
        math.max(0.0, _selectedTrack.targetTimeSeconds - elapsedSeconds);
    final int chronoBonus = (timeSaved * 45.0).round() + 300;
    final int rawTotal = distancePoints +
        blossomPoints +
        slalomPoints +
        jumpAndMogulPoints +
        chronoBonus;
    final int finalScore =
        (rawTotal * _selectedEdition.scoreMultiplier).round();

    int stars = 1;
    if (finalScore >= 4200) {
      stars = 3;
    } else if (finalScore >= 2600) {
      stars = 2;
    }

    lastRunBreakdown = SkiScoreBreakdown(
      distancePoints: distancePoints,
      blossomPoints: blossomPoints,
      slalomPoints: slalomPoints,
      jumpAndMogulPoints: jumpAndMogulPoints,
      chronoBonusPoints: chronoBonus,
      editionMultiplier: _selectedEdition.scoreMultiplier,
      totalScore: finalScore,
      starsEarned: stars,
      elapsedSeconds: elapsedSeconds,
      blossomsCollected: blossomsCollected,
      slalomPassed: slalomPassed,
      jumpsCompleted: jumpsCompleted,
      mogulsAbsorbed: mogulsAbsorbed,
      maxJumpHeightMeters: maxJumpHeightMeters,
    );

    final int prevBest = bestScoreForTrack(_selectedTrack);
    lastRunIsNewRecord = finalScore > prevBest;

    final SkiHighscoreEntry newEntry = SkiHighscoreEntry(
      id: 'run_${_selectedTrack.id}_${_highscores.length + 1}',
      playerName: 'Vivienne (Toi)',
      trackId: _selectedTrack,
      edition: _selectedEdition,
      score: finalScore,
      timeSeconds: elapsedSeconds,
      maxJumpMeters: maxJumpHeightMeters,
      blossomsCollected: blossomsCollected,
      slalomPassed: slalomPassed,
      stars: stars,
      isPlayerRun: true,
    );

    _highscores.add(newEntry);
    _highscores.sort(
      (SkiHighscoreEntry a, SkiHighscoreEntry b) => b.score.compareTo(a.score),
    );
    final List<SkiHighscoreEntry> trackBoard = highscoresForTrack(_selectedTrack);
    lastRunRank = trackBoard.indexOf(newEntry) + 1;

    onHapticEvent?.call(SkiHapticEvent.trackFinished);
  }

  /// Convenience helper for finishing or recording a run in automated tests or debug.
  void forceFinishRunForTest() {
    playerZ = _selectedTrack.lengthMeters;
    _completeRunAtChalet();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Complete Deterministic 3D World Generation for All 3 Tracks
  // ---------------------------------------------------------------------------

  void _resetSkierKinematics() {
    playerZ = 0.0;
    playerLateralOffset = 0.0;
    playerY = 0.0;
    playerVx = 0.0;
    playerVy = 0.0;
    speedKmh = _selectedTrack.baseSpeedKmh;
    playerRollRadians = 0.0;
    animState = VivienneSkiAnimState.glidingRearNeutral;
    currentAerialTrick = SkiAerialTrickKind.none;
    trickSpinAngle = 0.0;
    trickFlipAngle = 0.0;
    trickProgress = 0.0;
    _expectedFlightDuration = 1.15;
    _rampTrickCounter = 0;
    currentAnimScaleX = 1.0;
    currentAnimScaleY = 1.0;
    armRaiseProgress = 0.08;
    speedyBagSwingRadians = 0.0;
    _speedyBagAngularVel = 0.0;
    snowballCrashTimer = 0.0;
    snowballRotationRadians = 0.0;
    lastPineCollisionZone = null;
    _mogulSquashTimer = 0.0;
    _launchStretchTimer = 0.0;
    _landingSquashTimer = 0.0;
    _stumbleTimer = 0.0;
    _stumbleCooldown = 0.0;
    _speedBoostTimer = 0.0;

    elapsedSeconds = 0.0;
    airtimeSeconds = 0.0;
    totalAirtimeSeconds = 0.0;
    currentJumpHeightMeters = 0.0;
    maxJumpHeightMeters = 0.0;
    blossomsCollected = 0;
    blossomPoints = 0;
    slalomPassed = 0;
    slalomCombo = 0;
    maxSlalomCombo = 0;
    slalomPoints = 0;
    mogulsAbsorbed = 0;
    jumpsCompleted = 0;
    jumpAndMogulPoints = 0;
    lastRunBreakdown = null;
    lastRunRank = null;
    lastRunIsNewRecord = false;
    skiTrailHistory.clear();
    callouts.clear();
    _initAmbientSnowflakes();
  }

  void _generateTrackWorld(SkiTrackId track, int trackSeed) {
    worldProps.clear();
    moguls.clear();
    jumpRamps.clear();
    slalomGates.clear();
    blossoms.clear();

    final math.Random rng = math.Random(trackSeed ^ (track.index * 7919));
    final double length = track.lengthMeters;
    final double halfW = track.trackHalfWidthMeters;
    final bool slalomFull = _selectedGameMode == SkiGameMode.slalomComplet;
    int nextPropId = 1;
    int spectatorCycleIdx = 0;

    void addVivienneSpectator({
      required double z,
      required bool isLeftSide,
      double borderOffset = 2.05,
      double scale = 1.0,
    }) {
      final VivienneSkiEdition edition = VivienneSkiEdition
          .values[spectatorCycleIdx % VivienneSkiEdition.values.length];
      final VivienneSpectatorCheerStyle cheer = VivienneSpectatorCheerStyle
          .values[(spectatorCycleIdx * 2 + (isLeftSide ? 0 : 1)) %
              VivienneSpectatorCheerStyle.values.length];
      final double sideSign = isLeftSide ? -1.0 : 1.0;
      worldProps.add(
        SkiWorldProp3D(
          id: nextPropId++,
          kind: SkiPropKind.vivienneSpectator,
          x: trackCenterOffsetX(z) + sideSign * (halfW + borderOffset),
          z: z,
          scale: scale,
          variant: spectatorCycleIdx,
          spectatorEdition: edition,
          spectatorCheerStyle: cheer,
        ),
      );
      spectatorCycleIdx++;
    }

    // 1. Start Arch (`z = 8m`), Finish Arch (`z = length`) & Expanded 16-Building Alpine Finish Village (`v1.5.0`)
    worldProps.add(
      SkiWorldProp3D(
        id: nextPropId++,
        kind: SkiPropKind.startArch,
        x: trackCenterOffsetX(8.0),
        z: 8.0,
        scale: 1.0,
      ),
    );
    worldProps.add(
      SkiWorldProp3D(
        id: nextPropId++,
        kind: SkiPropKind.finishArch,
        x: trackCenterOffsetX(length),
        z: length,
        scale: 1.15,
      ),
    );

    final List<(double x, double z)> villageChaletFootprints =
        <(double, double)>[];
    void addVillageBuilding({
      required double z,
      required double lateralFromCenter,
      required double scale,
      required int variant,
    }) {
      final double bx = trackCenterOffsetX(z) + lateralFromCenter;
      villageChaletFootprints.add((bx, z));
      worldProps.add(
        SkiWorldProp3D(
          id: nextPropId++,
          kind: SkiPropKind.alpineChalet,
          x: bx,
          z: z,
          scale: scale,
          variant: variant % 3,
        ),
      );
    }

    // 1a. Approach Boulevard of the Resort Village (`8` staggered chalets along the final ~85m)
    final List<(double dzBeforeFinish, double lat, double scale, int variant)>
        approachVillageSpecs = <(double, double, double, int)>[
      (82.0, -(halfW + 8.0), 1.18, 0),
      (74.0, halfW + 8.8, 1.22, 1),
      (60.0, -(halfW + 14.2), 1.30, 2),
      (52.0, halfW + 14.8, 1.28, 0),
      (38.0, -(halfW + 7.4), 1.18, 2),
      (30.0, halfW + 7.8, 1.20, 1),
      (16.0, -(halfW + 12.6), 1.26, 1),
      (11.0, halfW + 12.4, 1.24, 2),
    ];
    for (final (double dz, double lat, double sc, int v)
        in approachVillageSpecs) {
      addVillageBuilding(
        z: length - dz,
        lateralFromCenter: lat,
        scale: sc,
        variant: v,
      );
    }

    // 1b. Multi-Row Alpine Village Amphitheater Plaza behind the Finish Arch (`8` buildings, `16` total!)
    final List<(double dzAfterFinish, double lat, double scale, int variant)>
        plazaVillageSpecs = <(double, double, double, int)>[
      (13.0, 11.4, 1.32, 2),
      (15.0, -11.6, 1.28, 0),
      (27.0, 20.2, 1.36, 1),
      (29.0, -20.2, 1.34, 2),
      (42.0, 7.8, 1.40, 1),
      (45.0, -8.2, 1.36, 0),
      (62.0, 15.2, 1.44, 0),
      (68.0, -1.4, 1.52, 1),
    ];
    for (final (double dz, double lat, double sc, int v) in plazaVillageSpecs) {
      addVillageBuilding(
        z: length + dz,
        lateralFromCenter: lat,
        scale: sc,
        variant: v,
      );
    }

    // 2a. Lateral `LV_NEO` 3D Banners (`SkiPropKind.lvBannerPost`) along BOTH sides every ~26m
    for (double bz = 22.0; bz <= length - 18.0; bz += 26.0) {
      final double cx = trackCenterOffsetX(bz);
      worldProps.add(
        SkiWorldProp3D(
          id: nextPropId++,
          kind: SkiPropKind.lvBannerPost,
          x: cx - (halfW + 0.9),
          z: bz,
          scale: 1.0,
          variant: 0,
        ),
      );
      worldProps.add(
        SkiWorldProp3D(
          id: nextPropId++,
          kind: SkiPropKind.lvBannerPost,
          x: cx + (halfW + 0.9),
          z: bz,
          scale: 1.0,
          variant: 1,
        ),
      );
    }

    // 2b. Chairlifts Strictly Bounded (`2 <= count <= 5`: 3 Green, 4 Blue, 5 Black, `v1.5.0`)
    final int cableCount = track.cableCarCount.clamp(2, 5);
    const double cableStartZ = 155.0;
    final double cableEndZ = math.max(cableStartZ + 120.0, length - 145.0);
    for (int cableIdx = 0; cableIdx < cableCount; cableIdx++) {
      final double frac =
          cableCount <= 1 ? 0.5 : (cableIdx / (cableCount - 1).toDouble());
      final double cz = cableStartZ + (cableEndZ - cableStartZ) * frac;
      worldProps.add(
        SkiWorldProp3D(
          id: nextPropId++,
          kind: SkiPropKind.cableCarPylon,
          x: trackCenterOffsetX(cz),
          z: cz,
          scale: 1.0,
          variant: cableIdx,
        ),
      );
    }

    int snowmanIdx = 0;
    for (double sz = 36.0; sz <= length - 40.0; sz += 82.0) {
      final double side = snowmanIdx.isEven ? -1.0 : 1.0;
      worldProps.add(
        SkiWorldProp3D(
          id: nextPropId++,
          kind: SkiPropKind.cartoonSnowman,
          x: trackCenterOffsetX(sz) + side * (halfW + 3.15),
          z: sz,
          scale: 1.05,
          variant: snowmanIdx++,
        ),
      );
    }

    int pennantIdx = 0;
    for (double pz = 30.0; pz <= length - 32.0; pz += 58.0) {
      final bool leftSide = pennantIdx.isOdd;
      final double side = leftSide ? -1.0 : 1.0;
      final VivienneSkiEdition ed = VivienneSkiEdition
          .values[pennantIdx % VivienneSkiEdition.values.length];
      final VivienneSpectatorCheerStyle cheer = VivienneSpectatorCheerStyle
          .values[(pennantIdx + 1) % VivienneSpectatorCheerStyle.values.length];
      worldProps.add(
        SkiWorldProp3D(
          id: nextPropId++,
          kind: SkiPropKind.flutteringPennantPost,
          x: trackCenterOffsetX(pz) + side * (halfW + 2.45),
          z: pz,
          scale: 1.0,
          variant: pennantIdx++,
          spectatorEdition: ed,
          spectatorCheerStyle: cheer,
        ),
      );
    }

    // 2c. 3D Vivienne Spectators (`speedyV03`, `wonderland`, `giantDenim`) along BOTH borders!
    // Cheering Start & Finish tribune groups:
    addVivienneSpectator(z: 14.5, isLeftSide: true, borderOffset: 1.85, scale: 1.04);
    addVivienneSpectator(z: 16.0, isLeftSide: false, borderOffset: 1.85, scale: 1.04);
    addVivienneSpectator(z: 19.5, isLeftSide: true, borderOffset: 2.25, scale: 0.98);
    addVivienneSpectator(z: 21.0, isLeftSide: false, borderOffset: 2.25, scale: 0.98);
    addVivienneSpectator(
      z: length - 12.0,
      isLeftSide: true,
      borderOffset: 1.95,
      scale: 1.05,
    );
    addVivienneSpectator(
      z: length - 10.5,
      isLeftSide: false,
      borderOffset: 1.95,
      scale: 1.05,
    );
    addVivienneSpectator(
      z: length - 5.5,
      isLeftSide: true,
      borderOffset: 2.25,
      scale: 1.02,
    );
    addVivienneSpectator(
      z: length - 4.5,
      isLeftSide: false,
      borderOffset: 2.25,
      scale: 1.02,
    );

    // Continuous 3D Vivienne spectators along both piste borders every ~28m!
    for (double spZ = 28.0; spZ <= length - 20.0; spZ += 28.0) {
      addVivienneSpectator(
        z: spZ,
        isLeftSide: true,
        borderOffset: 1.85 + (spectatorCycleIdx % 3) * 0.25,
        scale: 0.96 + (spectatorCycleIdx % 3) * 0.05,
      );
      addVivienneSpectator(
        z: spZ + 13.5,
        isLeftSide: false,
        borderOffset: 1.85 + (spectatorCycleIdx % 3) * 0.25,
        scale: 0.96 + (spectatorCycleIdx % 3) * 0.05,
      );
    }

    int cannonIdx = 0;
    for (double kz = 58.0; kz <= length - 50.0; kz += 108.0) {
      final double side = cannonIdx.isEven ? 1.0 : -1.0;
      worldProps.add(
        SkiWorldProp3D(
          id: nextPropId++,
          kind: SkiPropKind.snowCannon,
          x: trackCenterOffsetX(kz) + side * (halfW + 3.45),
          z: kz,
          scale: 1.0,
          variant: cannonIdx++,
        ),
      );
    }

    int midChaletIdx = 0;
    for (double hz = 148.0; hz <= length - 150.0; hz += 210.0) {
      final double side = midChaletIdx.isEven ? 1.0 : -1.0;
      worldProps.add(
        SkiWorldProp3D(
          id: nextPropId++,
          kind: SkiPropKind.alpineChalet,
          x: trackCenterOffsetX(hz) + side * (halfW + 10.5),
          z: hz,
          scale: 1.18,
          variant: midChaletIdx++,
        ),
      );
    }

    bool overlapsVillageChalet(double px, double pz) {
      for (final (double cx, double cz) in villageChaletFootprints) {
        if ((px - cx).abs() < 5.2 && (pz - cz).abs() < 6.4) {
          return true;
        }
      }
      return false;
    }

    // 2d. Bordering Snow-Laden 3D Pine Forest (pushed slightly outward behind border spectators!)
    final double borderStep = (length - 30.0) / track.pineTreeCount;
    for (int i = 0; i < track.pineTreeCount; i++) {
      final double zLeft = 18.0 + i * borderStep;
      final double cLeft = trackCenterOffsetX(zLeft);
      final double leftMargin = halfW + 3.25 + rng.nextDouble() * 8.8;
      final double leftX = cLeft - leftMargin;
      if (!overlapsVillageChalet(leftX, zLeft)) {
        worldProps.add(
          SkiWorldProp3D(
            id: nextPropId++,
            kind: i % 4 == 0
                ? SkiPropKind.giantSnowPine
                : SkiPropKind.alpinePineTree,
            x: leftX,
            z: zLeft,
            scale: 0.88 + rng.nextDouble() * 0.52,
            variant: i % 3,
            snowLoad: 0.85 + rng.nextDouble() * 0.30,
            hitRadius: 1.35,
          ),
        );
      }

      final double zRight = zLeft + borderStep * 0.48;
      final double cRight = trackCenterOffsetX(zRight);
      final double rightMargin = halfW + 3.25 + rng.nextDouble() * 8.8;
      final double rightX = cRight + rightMargin;
      final SkiPropKind rightKind =
          (track == SkiTrackId.blackVendomePeaks && i % 5 == 2)
              ? SkiPropKind.crystalIceRock
              : (i % 3 == 0
                  ? SkiPropKind.giantSnowPine
                  : SkiPropKind.alpinePineTree);
      if (!overlapsVillageChalet(rightX, zRight)) {
        worldProps.add(
          SkiWorldProp3D(
            id: nextPropId++,
            kind: rightKind,
            x: rightX,
            z: zRight,
            scale: 0.90 + rng.nextDouble() * 0.50,
            variant: (i + 1) % 3,
            snowLoad: 0.85 + rng.nextDouble() * 0.30,
            hitRadius: 1.35,
          ),
        );
      }
    }

    // 3. Slalom Gates (`v1.4.0`): Strict Left (Red/Gold) <-> Right (Blue/Azure) alternation!
    final int gateCount =
        slalomFull ? track.slalomModeGateCount : track.slalomGateCount;
    final double gateStartZ = slalomFull ? 36.0 : 54.0;
    final double gateEndZ = slalomFull ? (length - 38.0) : (length - 58.0);
    final double gateHalfWidth = slalomFull
        ? (track == SkiTrackId.greenBlossomValley
            ? 3.55
            : (track == SkiTrackId.blueAsnieresForest ? 3.40 : 3.25))
        : (track == SkiTrackId.greenBlossomValley
            ? 4.20
            : (track == SkiTrackId.blueAsnieresForest ? 3.85 : 3.50));

    for (int i = 0; i < gateCount; i++) {
      final double tGate =
          gateCount <= 1 ? 0.0 : (i / (gateCount - 1).toDouble());
      final double gz = gateStartZ + (gateEndZ - gateStartZ) * tGate;
      final double cx = trackCenterOffsetX(gz);
      final bool isLeft = i.isEven;
      final double swingRatio = 0.45 + 0.045 * ((i % 3) / 2.0);
      final double swingX = (isLeft ? -1.0 : 1.0) * (halfW * swingRatio);
      slalomGates.add(
        SkiSlalomGate3D(
          id: i + 1,
          centerX: cx + swingX,
          z: gz,
          halfWidth: gateHalfWidth,
          isLeftGate: isLeft,
          isGoldRed: isLeft,
          gateNumber: i + 1,
        ),
      );
    }

    // 4. Jump Ramps (`6`, `9`, `12`) alternating ALL 3 Size Tiers (`small`, `medium`, `large`)!
    final int rampCount = track.jumpRampCount;
    final double tailStartZ = 192.0;
    final double tailSpan = math.max(80.0, length - tailStartZ - 82.0);
    for (int i = 0; i < rampCount; i++) {
      final SkiRampSizeTier tier =
          SkiRampSizeTier.values[i % SkiRampSizeTier.values.length];
      double rz;
      if (i == 0) {
        rz = 68.0;
      } else if (i == 1) {
        rz = 104.0;
      } else if (i == 2) {
        rz = 144.0;
      } else {
        final int remCount = math.max(1, rampCount - 3);
        rz = tailStartZ + tailSpan * ((i - 2.5) / remCount);
      }

      // In Full Slalom mode, place ramps opposite the nearest gate so gates stay wide open!
      double lateral;
      SkiSlalomGate3D? nearestGate;
      double minDz = 9999.0;
      for (final SkiSlalomGate3D g in slalomGates) {
        final double dz = (g.z - rz).abs();
        if (dz < minDz) {
          minDz = dz;
          nearestGate = g;
        }
      }
      if (slalomFull && nearestGate != null && minDz < 14.0) {
        lateral = (nearestGate.isLeftGate ? 1.0 : -1.0) * (halfW * 0.34);
      } else if (i == 0) {
        lateral = -halfW * 0.20;
      } else if (i == 1) {
        lateral = halfW * 0.22;
      } else if (i == 2) {
        lateral = -halfW * 0.06;
      } else {
        lateral = (i.isEven ? -1.0 : 1.0) *
            (1.6 + rng.nextDouble() * (halfW * 0.30));
      }

      final double cx = trackCenterOffsetX(rz);
      jumpRamps.add(
        SkiJumpRamp3D.fromTier(
          id: i + 1,
          x: cx + lateral,
          z: rz,
          sizeTier: tier,
        ),
      );

      // Extra cheering Vivienne spectators flanking Big Air / Medium ramps!
      if (tier != SkiRampSizeTier.small) {
        addVivienneSpectator(
          z: rz + 2.5,
          isLeftSide: lateral <= 0.0,
          borderOffset: 1.75,
          scale: 1.05,
        );
      }
    }

    // 5. Dense Integrated 3D Mogul Fields (`22`, `34`, `48`) baked into `snowSurfaceHeightAt`!
    final int mogulCount = track.mogulCount;
    final double mogulSpan = length - 66.0;
    final double baseMogulHeight = track == SkiTrackId.greenBlossomValley
        ? 0.92
        : (track == SkiTrackId.blueAsnieresForest ? 1.10 : 1.28);
    for (int i = 0; i < mogulCount; i++) {
      double mz = 40.0 + (mogulSpan * i / math.max(1, mogulCount - 1));
      for (final SkiJumpRamp3D r in jumpRamps) {
        if ((mz - r.z).abs() < r.length * 0.65 + 3.5) {
          mz += r.length * 0.65 + 4.5;
        }
      }
      mz = mz.clamp(34.0, length - 24.0);
      final double cx = trackCenterOffsetX(mz);

      // Alternate lateral waves across left, center, and right of the piste
      double offset = math.sin(i * 1.75 + 0.4) * (halfW * 0.56);
      if (slalomFull) {
        for (final SkiSlalomGate3D g in slalomGates) {
          if ((g.z - mz).abs() < 7.5 &&
              ((cx + offset) - g.centerX).abs() < g.halfWidth + 1.8) {
            offset = (g.isLeftGate ? 1.0 : -1.0) * (halfW * 0.42);
            break;
          }
        }
      }

      // 3 mogul profiles: quick rhythm bump, medium carving mogul, large alpine whaleback!
      final int profile = i % 3;
      final double rx = profile == 0 ? 2.55 : (profile == 1 ? 3.35 : 4.20);
      final double rz = profile == 0 ? 3.95 : (profile == 1 ? 5.15 : 6.40);
      final double hScale = profile == 0 ? 0.86 : (profile == 1 ? 1.08 : 1.32);

      moguls.add(
        SkiMogul3D(
          id: i + 1,
          x: cx + offset,
          z: mz,
          radiusX: rx,
          radiusZ: rz,
          heightMeters: baseMogulHeight * hScale,
        ),
      );
    }

    // 6. On-Piste Pine Tree Islands with Orange Safety Pads (`v1.5.0`, clear of ramps & slalom gates!)
    void addOnPisteTreeIfClear({
      required double tz,
      required double preferredSide,
      required double lateralDist,
      required double scale,
      required int variant,
      required bool giant,
    }) {
      for (final SkiJumpRamp3D r in jumpRamps) {
        if ((tz - r.z).abs() < 15.0) return;
      }
      double side = preferredSide;
      if (slalomFull) {
        for (final SkiSlalomGate3D g in slalomGates) {
          if ((g.z - tz).abs() < 14.0) {
            side = g.isLeftGate ? 1.0 : -1.0;
            break;
          }
        }
      }
      final double cx = trackCenterOffsetX(tz);
      worldProps.add(
        SkiWorldProp3D(
          id: nextPropId++,
          kind: giant ? SkiPropKind.giantSnowPine : SkiPropKind.alpinePineTree,
          x: cx + side * lateralDist,
          z: tz,
          scale: scale,
          variant: variant % 3,
          hitRadius: 1.30,
          isOnPiste: true,
        ),
      );
    }

    // Early & pre-village signature on-piste trees (safely opposite Ramp #0 & Ramp #1 lines!)
    addOnPisteTreeIfClear(
      tz: 88.0,
      preferredSide: 1.0,
      lateralDist: halfW * 0.42,
      scale: 0.98,
      variant: 0,
      giant: false,
    );
    addOnPisteTreeIfClear(
      tz: 122.0,
      preferredSide: -1.0,
      lateralDist: halfW * 0.42,
      scale: 1.04,
      variant: 1,
      giant: true,
    );
    addOnPisteTreeIfClear(
      tz: length - 94.0,
      preferredSide: -1.0,
      lateralDist: halfW * 0.38,
      scale: 1.02,
      variant: 2,
      giant: false,
    );
    addOnPisteTreeIfClear(
      tz: length - 30.0,
      preferredSide: -1.0,
      lateralDist: halfW * 0.42,
      scale: 1.00,
      variant: 0,
      giant: false,
    );

    final int islandCount = slalomFull
        ? (track == SkiTrackId.greenBlossomValley ? 5 : 10)
        : (track == SkiTrackId.greenBlossomValley
            ? 10
            : (track == SkiTrackId.blueAsnieresForest ? 20 : 30));
    for (int i = 0; i < islandCount; i++) {
      final double tz = 135.0 + ((length - 210.0) * (i + 0.5) / islandCount);
      final double side = (i % 2 == 0 ? -1.0 : 1.0);
      final double lateralDist = 3.6 + (rng.nextDouble() * (halfW * 0.38));
      addOnPisteTreeIfClear(
        tz: tz,
        preferredSide: side,
        lateralDist: lateralDist,
        scale: 0.88 + rng.nextDouble() * 0.28,
        variant: i,
        giant: i % 5 == 0,
      );
    }

    // 7. Blossom 3D Flowers (`35`, `50`, `70`) along slalom / carving lines & above Jump Ramps!
    int blossomId = 1;
    for (final SkiJumpRamp3D ramp in jumpRamps) {
      if (blossomId > track.blossomCount - 6) break;
      for (int arc = 0; arc < 3 && blossomId <= track.blossomCount; arc++) {
        final double dz = 4.5 + arc * 4.6;
        final double bz = ramp.z + dz;
        final double peakScale = ramp.sizeTier == SkiRampSizeTier.large
            ? 1.35
            : (ramp.sizeTier == SkiRampSizeTier.medium ? 1.05 : 0.82);
        final double arcY =
            (2.1 + math.sin((arc + 1) * 0.85) * 2.1) * peakScale;
        blossoms.add(
          SkiBlossomCollectible3D(
            id: blossomId++,
            x: ramp.x + (bz - ramp.z) * 0.04,
            y: arcY,
            z: bz,
            isStarGold: arc == 1 ||
                ramp.sizeTier == SkiRampSizeTier.large ||
                track == SkiTrackId.blackVendomePeaks,
            points: arc == 1 ? 150 : 80,
            phaseOffset: blossomId * 0.55,
          ),
        );
      }
    }

    final int remainingBlossoms = track.blossomCount - blossoms.length;
    for (int i = 0; i < remainingBlossoms; i++) {
      final double frac = i / math.max(1, remainingBlossoms);
      final double bz = 28.0 + (length - 70.0) * frac;
      final double cx = trackCenterOffsetX(bz);
      double ribbonOffset = math.sin(bz * 0.048) * (halfW * 0.34);
      if (slalomFull && slalomGates.isNotEmpty) {
        final int gi =
            (frac * (slalomGates.length - 1)).floor().clamp(0, slalomGates.length - 1);
        final SkiSlalomGate3D gA = slalomGates[gi];
        final SkiSlalomGate3D gB =
            slalomGates[math.min(gi + 1, slalomGates.length - 1)];
        final double segSpan = math.max(1.0, gB.z - gA.z);
        final double segT = ((bz - gA.z) / segSpan).clamp(0.0, 1.0);
        final double smoothS = 0.5 - 0.5 * math.cos(segT * math.pi);
        final double targetX = gA.centerX + (gB.centerX - gA.centerX) * smoothS;
        ribbonOffset = targetX - cx;
      }
      final bool starGold =
          (track == SkiTrackId.blackVendomePeaks && i % 3 == 0) || (i % 6 == 0);
      blossoms.add(
        SkiBlossomCollectible3D(
          id: blossomId++,
          x: cx + ribbonOffset,
          y: 0.45,
          z: bz,
          isStarGold: starGold,
          points: starGold ? 140 : 60,
          phaseOffset: i * 0.42,
        ),
      );
    }
  }

  void _seedDefaultHighscores() {
    _highscores
      ..clear()
      ..addAll(const <SkiHighscoreEntry>[
        // Piste Verte — Vallée Blossom Ensoleillée
        SkiHighscoreEntry(
          id: 'seed_green_1',
          playerName: 'Vivienne Atelier',
          trackId: SkiTrackId.greenBlossomValley,
          edition: VivienneSkiEdition.speedyV03,
          score: 5680,
          timeSeconds: 44.2,
          maxJumpMeters: 5.1,
          blossomsCollected: 31,
          slalomPassed: 10,
          stars: 3,
        ),
        SkiHighscoreEntry(
          id: 'seed_green_2',
          playerName: 'Camille Asnières',
          trackId: SkiTrackId.greenBlossomValley,
          edition: VivienneSkiEdition.giantDenim,
          score: 4590,
          timeSeconds: 47.8,
          maxJumpMeters: 4.5,
          blossomsCollected: 27,
          slalomPassed: 8,
          stars: 3,
        ),
        SkiHighscoreEntry(
          id: 'seed_green_3',
          playerName: 'Louis Chamonix',
          trackId: SkiTrackId.greenBlossomValley,
          edition: VivienneSkiEdition.wonderland,
          score: 3450,
          timeSeconds: 51.6,
          maxJumpMeters: 3.9,
          blossomsCollected: 20,
          slalomPassed: 7,
          stars: 2,
        ),
        // Piste Bleue — Forêt des Sapins d'Asnières
        SkiHighscoreEntry(
          id: 'seed_blue_1',
          playerName: 'Vivienne Wonderland',
          trackId: SkiTrackId.blueAsnieresForest,
          edition: VivienneSkiEdition.wonderland,
          score: 8940,
          timeSeconds: 54.5,
          maxJumpMeters: 6.2,
          blossomsCollected: 45,
          slalomPassed: 13,
          stars: 3,
        ),
        SkiHighscoreEntry(
          id: 'seed_blue_2',
          playerName: 'Gaston Courchevel',
          trackId: SkiTrackId.blueAsnieresForest,
          edition: VivienneSkiEdition.giantDenim,
          score: 7420,
          timeSeconds: 58.9,
          maxJumpMeters: 5.6,
          blossomsCollected: 38,
          slalomPassed: 11,
          stars: 3,
        ),
        SkiHighscoreEntry(
          id: 'seed_blue_3',
          playerName: 'Éléonore Megève',
          trackId: SkiTrackId.blueAsnieresForest,
          edition: VivienneSkiEdition.speedyV03,
          score: 5490,
          timeSeconds: 63.4,
          maxJumpMeters: 4.8,
          blossomsCollected: 29,
          slalomPassed: 9,
          stars: 2,
        ),
        // Piste Noire Or — Cimes Étoilées Vendôme
        SkiHighscoreEntry(
          id: 'seed_black_1',
          playerName: 'Vivienne Giant Denim',
          trackId: SkiTrackId.blackVendomePeaks,
          edition: VivienneSkiEdition.giantDenim,
          score: 14850,
          timeSeconds: 64.2,
          maxJumpMeters: 8.2,
          blossomsCollected: 65,
          slalomPassed: 17,
          stars: 3,
        ),
        SkiHighscoreEntry(
          id: 'seed_black_2',
          playerName: 'Céleste Zermatt',
          trackId: SkiTrackId.blackVendomePeaks,
          edition: VivienneSkiEdition.wonderland,
          score: 12180,
          timeSeconds: 68.4,
          maxJumpMeters: 7.4,
          blossomsCollected: 56,
          slalomPassed: 15,
          stars: 3,
        ),
        SkiHighscoreEntry(
          id: 'seed_black_3',
          playerName: 'Henri Val-d\'Isère',
          trackId: SkiTrackId.blackVendomePeaks,
          edition: VivienneSkiEdition.speedyV03,
          score: 9240,
          timeSeconds: 73.1,
          maxJumpMeters: 6.5,
          blossomsCollected: 43,
          slalomPassed: 12,
          stars: 2,
        ),
      ]);
  }
}
