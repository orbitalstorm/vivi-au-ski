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
/// for `VIVI AU SKI : Descente Royale 3D` (`v1.0.0`).
class SkiGameEngine extends ChangeNotifier {
  SkiGameEngine({
    SkiTrackId initialTrack = SkiTrackId.greenBlossomValley,
    VivienneSkiEdition initialEdition = VivienneSkiEdition.speedyV03,
    int seed = 2026,
    this.onHapticEvent,
  })  : _selectedTrack = initialTrack,
        _selectedEdition = initialEdition,
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
  SkiAerialTrickKind currentAerialTrick = SkiAerialTrickKind.victoryVArms;

  double currentAnimScaleX = 1.0;
  double currentAnimScaleY = 1.0;
  double armRaiseProgress = 0.08;
  double speedyBagSwingRadians = 0.0;
  double _speedyBagAngularVel = 0.0;
  double scarfWavePhase = 0.0;
  double ambientTime = 0.0;

  static const double snowballCrashDuration = 1.15;
  double snowballCrashTimer = 0.0;
  double snowballRotationRadians = 0.0;

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

  void startRun({SkiTrackId? track, int? seed}) {
    if (track != null) {
      _selectedTrack = track;
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
    startRun(track: _selectedTrack, seed: _seed);
  }

  void startNextTrack() {
    startRun(track: _selectedTrack.nextTrack, seed: _seed + 1);
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
  /// or full `00..23` spin frame when executing `blossomSpin360` in midair!
  int get activeSkierTurntableFrameIndex {
    if (animState == VivienneSkiAnimState.airborneCelebration &&
        currentAerialTrick == SkiAerialTrickKind.blossomSpin360) {
      final double spinAngle = 180.0 + (airtimeSeconds * 360.0);
      return VivienneTurntableSpec.frameIndexForAngle(spinAngle);
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

  /// Continuous vertical downhill profile + natural rolling alpine relief at `z`.
  double trackElevationY(double z) {
    final double slopeRad = _selectedTrack.slopeDegrees * math.pi / 180.0;
    final double baseDrop = -z * math.tan(slopeRad);
    final double undulation = math.sin(z * 0.036) * 1.35 +
        math.cos(z * 0.074) * 0.58;
    return baseDrop + undulation;
  }

  /// Pronounced alpine crests ("ruptures de pente") and valley plunges relative to `playerZ`.
  double relativeReliefAtZ(double z) {
    final double startFade = (z / 36.0).clamp(0.0, 1.0);
    final double endFade =
        ((_selectedTrack.lengthMeters - z) / 55.0).clamp(0.0, 1.0);
    final double slopeScale =
        0.88 + (_selectedTrack.slopeDegrees / 45.0) * 0.92;
    return (math.sin(z * 0.036) * 1.28 + math.cos(z * 0.074) * 0.56) *
        slopeScale *
        startFade *
        endFade;
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

    // 1. High-Gradient Downhill Speed Physics (`24°`, `34°`, `45°`)
    final double tiltAbs = effectiveTiltX.abs();
    final double editionMaxKmh =
        _selectedTrack.maxSpeedKmh * _selectedEdition.glideBonusMultiplier;
    final double carveDragFactor = 1.0 - tiltAbs * 0.14;
    final double offPisteRatio =
        (playerLateralOffset.abs() / _selectedTrack.trackHalfWidthMeters);
    final double powderDragFactor = offPisteRatio > 0.96 ? 0.80 : 1.0;
    final double crashDragFactor = snowballCrashTimer > 0 ? 0.78 : 1.0;
    final double boostBonusKmh = _speedBoostTimer > 0 ? 18.0 : 0.0;
    final double crestPlungeBonus =
        math.max(0.0, -math.cos(playerZ * 0.036)) * 8.5;

    final double targetKmh = ((_selectedTrack.baseSpeedKmh +
                    (_selectedTrack.maxSpeedKmh - _selectedTrack.baseSpeedKmh) *
                        0.78 +
                    crestPlungeBonus) *
                _selectedEdition.glideBonusMultiplier *
                carveDragFactor *
                powderDragFactor *
                crashDragFactor +
            boostBonusKmh)
        .clamp(_selectedTrack.baseSpeedKmh * 0.65, editionMaxKmh + 16.0);

    final double accelRate = speedKmh < targetKmh ? 2.25 : 3.0;
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
        final double domeY =
            m.heightMeters * math.cos(math.sqrt(u2) * math.pi * 0.5);
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
          // High-speed crest pop!
          if (playerZ >= m.z &&
              playerVy <= 0.5 &&
              speedKmh > _selectedTrack.baseSpeedKmh * 1.05) {
            playerVy = 4.2 * _selectedEdition.jumpBoostMultiplier;
          }
        }
      }
    }

    // 4. Ski Jump Ramps (Tremplins 3D) Interaction
    for (int i = 0; i < jumpRamps.length; i++) {
      final SkiJumpRamp3D ramp = jumpRamps[i];
      final double zStart = ramp.z - ramp.length * 0.5;
      final double zEnd = ramp.z + ramp.length * 0.5;
      if (playerZ < zStart - 1.0 || prevZ > zEnd + 1.5) continue;

      final bool alignedX = (wx - ramp.x).abs() <= ramp.width * 0.58;
      if (!alignedX) continue;

      if (playerZ >= zStart && playerZ <= zEnd) {
        final double t = ((playerZ - zStart) / ramp.length).clamp(0.0, 1.0);
        final double deckY = t * ramp.heightMeters;
        if (playerY <= deckY + 0.65) {
          groundSurfaceY = math.max(groundSurfaceY, deckY);
          playerY = math.max(playerY, deckY);
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

    // 5. Vertical Airborne Kinematics (Gravity, Apex Celebration, Landing Impact)
    if (playerY > groundSurfaceY || playerVy > 0.0) {
      airtimeSeconds += clampedDt;
      totalAirtimeSeconds += clampedDt;
      const double skiGravity = 16.2;
      playerVy -= skiGravity * clampedDt;
      playerY += playerVy * clampedDt;

      if (playerY > currentJumpHeightMeters) {
        currentJumpHeightMeters = playerY;
      }
      if (playerY > maxJumpHeightMeters) {
        maxJumpHeightMeters = playerY;
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
      }
    } else {
      playerY = groundSurfaceY;
      playerVy = 0.0;
    }

    // 6. Slalom Gates Validation
    for (int i = 0; i < slalomGates.length; i++) {
      final SkiSlalomGate3D gate = slalomGates[i];
      if (gate.passed || gate.missed) continue;
      if (prevZ < gate.z && playerZ >= gate.z) {
        if ((wx - gate.centerX).abs() <= gate.halfWidth + 0.45) {
          slalomGates[i] = gate.copyWith(passed: true);
          slalomPassed++;
          slalomCombo++;
          if (slalomCombo > maxSlalomCombo) {
            maxSlalomCombo = slalomCombo;
          }
          final int gatePts = 100 + slalomCombo * 25;
          slalomPoints += gatePts;
          _speedBoostTimer = 0.9;
          _addCallout(
            'SLALOM ×$slalomCombo +$gatePts',
            const Color(0xFF00E676),
          );
          onHapticEvent?.call(SkiHapticEvent.slalomGate);
        } else {
          slalomGates[i] = gate.copyWith(missed: true);
          slalomCombo = 0;
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

    // 8. Pine Tree Snowball Crash (`alpinePineTree` & `giantSnowPine`, on-piste OR border)
    if (_stumbleCooldown <= 0.0 &&
        snowballCrashTimer <= 0.0 &&
        playerY < 1.55) {
      for (int i = 0; i < worldProps.length; i++) {
        final SkiWorldProp3D prop = worldProps[i];
        if (prop.kind != SkiPropKind.alpinePineTree &&
            prop.kind != SkiPropKind.giantSnowPine) {
          continue;
        }
        final bool sweptZ = prevZ <= prop.z && playerZ >= prop.z;
        if (!sweptZ && (prop.z - playerZ).abs() > 1.65) continue;
        final double dx = wx - prop.x;
        final double effectiveRadius =
            prop.hitRadius * (0.85 + prop.scale * 0.20);
        if (dx.abs() < effectiveRadius) {
          _triggerSnowballCrash(dx: dx, maxLat: maxLat);
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

  void _triggerJumpLaunch(SkiJumpRamp3D ramp) {
    final double speedRatio =
        (speedKmh / _selectedTrack.maxSpeedKmh).clamp(0.75, 1.25);
    playerVy = ramp.boostVy *
        _selectedEdition.jumpBoostMultiplier *
        (0.88 + 0.22 * speedRatio);
    playerY = math.max(playerY, ramp.heightMeters + 0.28);
    _launchStretchTimer = 0.20;
    _speedBoostTimer = 1.4;

    final List<SkiAerialTrickKind> tricks = SkiAerialTrickKind.values;
    currentAerialTrick = tricks[jumpsCompleted % tricks.length];
    jumpsCompleted++;

    final int bonus = currentAerialTrick.bonusPoints;
    jumpAndMogulPoints += bonus;
    _addCallout(
      '${currentAerialTrick.title} +$bonus !',
      const Color(0xFFFF4081),
    );
    _spawnPowderBurst(count: 14, upwardVy: 6.0);
    onHapticEvent?.call(SkiHapticEvent.rampLaunch);
  }

  void _updateAnimationState(double dt) {
    if (snowballCrashTimer > 0.0) {
      animState = VivienneSkiAnimState.snowballCrash;
    } else if (_stumbleTimer > 0.0) {
      animState = VivienneSkiAnimState.obstacleStumble;
    } else if (playerY > 0.42 || playerVy > 1.8) {
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
    final bool skisOnSnow = playerY <= 0.18;
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
  }) {
    final double wx = playerWorldX;
    for (int i = 0; i < count && snowParticles.length < 165; i++) {
      final double angle = (i / count) * math.pi * 2.0;
      final bool isNeedle = includePineNeedles && (i % 3 == 1);
      snowParticles.add(
        SkiSnowParticle3D(
          x: wx + math.cos(angle) * 0.55,
          y: math.max(0.18, playerY + 0.12),
          z: playerZ + math.sin(angle) * 0.55,
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

  void _addCallout(String text, Color color) {
    callouts.add(
      SkiFloatingCallout(
        text: text,
        color: color,
        life: 1.05,
        maxLife: 1.05,
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
    currentAerialTrick = SkiAerialTrickKind.victoryVArms;
    currentAnimScaleX = 1.0;
    currentAnimScaleY = 1.0;
    armRaiseProgress = 0.08;
    speedyBagSwingRadians = 0.0;
    _speedyBagAngularVel = 0.0;
    snowballCrashTimer = 0.0;
    snowballRotationRadians = 0.0;
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
    int nextPropId = 1;

    // 1. Start Arch (`z = 8m`) & Finish Arch + Alpine LV Chalet (`z = length`)
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
    worldProps.add(
      SkiWorldProp3D(
        id: nextPropId++,
        kind: SkiPropKind.alpineChalet,
        x: trackCenterOffsetX(length) + 8.5,
        z: length + 16.0,
        scale: 1.35,
      ),
    );
    worldProps.add(
      SkiWorldProp3D(
        id: nextPropId++,
        kind: SkiPropKind.alpineChalet,
        x: trackCenterOffsetX(length) - 9.5,
        z: length + 20.0,
        scale: 1.15,
      ),
    );

    // 2a. Lateral `LV_NEO` 3D Banners (`SkiPropKind.lvBannerPost`) along BOTH sides of the piste every ~26m!
    for (double bz = 22.0; bz <= length - 18.0; bz += 26.0) {
      final double cx = trackCenterOffsetX(bz);
      worldProps.add(
        SkiWorldProp3D(
          id: nextPropId++,
          kind: SkiPropKind.lvBannerPost,
          x: cx - (halfW + 0.9),
          z: bz,
          scale: 1.0,
          variant: 0, // Left piste border
        ),
      );
      worldProps.add(
        SkiWorldProp3D(
          id: nextPropId++,
          kind: SkiPropKind.lvBannerPost,
          x: cx + (halfW + 0.9),
          z: bz,
          scale: 1.0,
          variant: 1, // Right piste border
        ),
      );
    }

    // 2b. Animated Overhead Alpine Cable Cars (`SkiPropKind.cableCarPylon`),
    //     Waving Cartoon Snowmen (`cartoonSnowman`), Fluttering Pennants & Supporters (`flutteringPennantPost`),
    //     Active Snow Cannons (`snowCannon`) & Illuminated Mid-Slope Chalets (`alpineChalet`)
    int cableIdx = 0;
    for (double cz = 116.0; cz <= length - 75.0; cz += 175.0) {
      worldProps.add(
        SkiWorldProp3D(
          id: nextPropId++,
          kind: SkiPropKind.cableCarPylon,
          x: trackCenterOffsetX(cz),
          z: cz,
          scale: 1.0,
          variant: cableIdx++,
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
          x: trackCenterOffsetX(sz) + side * (halfW + 2.65),
          z: sz,
          scale: 1.05,
          variant: snowmanIdx++,
        ),
      );
    }

    int pennantIdx = 0;
    for (double pz = 30.0; pz <= length - 32.0; pz += 64.0) {
      final double side = pennantIdx.isOdd ? -1.0 : 1.0;
      worldProps.add(
        SkiWorldProp3D(
          id: nextPropId++,
          kind: SkiPropKind.flutteringPennantPost,
          x: trackCenterOffsetX(pz) + side * (halfW + 2.45),
          z: pz,
          scale: 1.0,
          variant: pennantIdx++,
        ),
      );
    }

    int cannonIdx = 0;
    for (double kz = 58.0; kz <= length - 50.0; kz += 108.0) {
      final double side = cannonIdx.isEven ? 1.0 : -1.0;
      worldProps.add(
        SkiWorldProp3D(
          id: nextPropId++,
          kind: SkiPropKind.snowCannon,
          x: trackCenterOffsetX(kz) + side * (halfW + 3.05),
          z: kz,
          scale: 1.0,
          variant: cannonIdx++, // even -> right side aiming left, odd -> left side aiming right
        ),
      );
    }

    int midChaletIdx = 0;
    for (double hz = 148.0; hz <= length - 120.0; hz += 210.0) {
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

    // 2c. Bordering Snow-Laden 3D Pine Forest (collidable off-piste for Snowball Crash!)
    final double borderStep = (length - 30.0) / track.pineTreeCount;
    for (int i = 0; i < track.pineTreeCount; i++) {
      final double zLeft = 18.0 + i * borderStep;
      final double cLeft = trackCenterOffsetX(zLeft);
      final double leftMargin = halfW + 1.85 + rng.nextDouble() * 9.2;
      worldProps.add(
        SkiWorldProp3D(
          id: nextPropId++,
          kind: i % 4 == 0
              ? SkiPropKind.giantSnowPine
              : SkiPropKind.alpinePineTree,
          x: cLeft - leftMargin,
          z: zLeft,
          scale: 0.88 + rng.nextDouble() * 0.52,
          variant: i % 3,
          snowLoad: 0.85 + rng.nextDouble() * 0.30,
          hitRadius: 1.35,
        ),
      );

      final double zRight = zLeft + borderStep * 0.48;
      final double cRight = trackCenterOffsetX(zRight);
      final double rightMargin = halfW + 1.85 + rng.nextDouble() * 9.2;
      final SkiPropKind rightKind =
          (track == SkiTrackId.blackVendomePeaks && i % 5 == 2)
              ? SkiPropKind.crystalIceRock
              : (i % 3 == 0
                  ? SkiPropKind.giantSnowPine
                  : SkiPropKind.alpinePineTree);
      worldProps.add(
        SkiWorldProp3D(
          id: nextPropId++,
          kind: rightKind,
          x: cRight + rightMargin,
          z: zRight,
          scale: 0.90 + rng.nextDouble() * 0.50,
          variant: (i + 1) % 3,
          snowLoad: 0.85 + rng.nextDouble() * 0.30,
          hitRadius: 1.35,
        ),
      );
    }

    // 3. Jump Ramps (`4`, `7`, `10`) — first ramp centered at `z = 95m` for instant action!
    final int rampCount = track.jumpRampCount;
    final double rampSpan = length - 190.0;
    for (int i = 0; i < rampCount; i++) {
      final double rz = i == 0
          ? 95.0
          : 95.0 + (rampSpan * i / (rampCount - 0.35));
      final double cx = trackCenterOffsetX(rz);
      final double lateral = i == 0
          ? 0.0
          : ((i.isEven ? -1.0 : 1.0) *
              (2.0 + rng.nextDouble() * (halfW * 0.32)));
      final bool isMega =
          track == SkiTrackId.blackVendomePeaks || (i == rampCount - 1);
      jumpRamps.add(
        SkiJumpRamp3D(
          id: i + 1,
          x: cx + lateral,
          z: rz,
          width: isMega ? 6.2 : 5.6,
          length: isMega ? 10.8 : 9.4,
          heightMeters: isMega ? 2.15 : 1.72,
          boostVy: isMega ? 14.4 : 12.4,
          label: isMega ? 'BIG AIR VENDÔME' : 'TREMPLIN BLOSSOM',
        ),
      );
    }

    // 4. Mogul Fields (`8`, `16`, `24`) — first mogul centered at `z = 52m`!
    final int mogulCount = track.mogulCount;
    final double mogulSpan = length - 150.0;
    for (int i = 0; i < mogulCount; i++) {
      double mz =
          i == 0 ? 52.0 : 52.0 + (mogulSpan * i / (mogulCount - 0.2));
      // Keep clear of jump ramps
      for (final SkiJumpRamp3D r in jumpRamps) {
        if ((mz - r.z).abs() < 12.0) {
          mz += 14.0;
        }
      }
      final double cx = trackCenterOffsetX(mz);
      final double offset = i == 0
          ? 0.0
          : math.sin(i * 1.9) * (halfW * 0.46);
      moguls.add(
        SkiMogul3D(
          id: i + 1,
          x: cx + offset,
          z: mz,
          radiusX: 2.6 + (i % 2) * 0.35,
          radiusZ: 4.0 + (i % 3) * 0.45,
          heightMeters: track == SkiTrackId.greenBlossomValley
              ? 0.76
              : (track == SkiTrackId.blueAsnieresForest ? 0.94 : 1.12),
        ),
      );
    }

    // 5. On-Piste Pine Tree Islands (Fairly spaced away from ramps & start/finish)
    final int islandCount = track == SkiTrackId.greenBlossomValley
        ? 10
        : (track == SkiTrackId.blueAsnieresForest ? 20 : 30);
    for (int i = 0; i < islandCount; i++) {
      final double tz = 135.0 + ((length - 210.0) * (i + 0.5) / islandCount);
      bool nearRamp = false;
      for (final SkiJumpRamp3D r in jumpRamps) {
        if ((tz - r.z).abs() < 16.0) {
          nearRamp = true;
          break;
        }
      }
      if (nearRamp) continue;

      final double cx = trackCenterOffsetX(tz);
      final double side = (i % 2 == 0 ? -1.0 : 1.0);
      final double offset = side * (3.2 + (rng.nextDouble() * (halfW * 0.42)));
      worldProps.add(
        SkiWorldProp3D(
          id: nextPropId++,
          kind: i % 5 == 0
              ? SkiPropKind.giantSnowPine
              : SkiPropKind.alpinePineTree,
          x: cx + offset,
          z: tz,
          scale: 0.88 + rng.nextDouble() * 0.28,
          variant: i % 3,
          hitRadius: 1.30,
          isOnPiste: true,
        ),
      );
    }

    // 6. Slalom Gates (`10`, `14`, `18`)
    final int gateCount = track.slalomGateCount;
    for (int i = 0; i < gateCount; i++) {
      final double gz = 72.0 + ((length - 140.0) * i / gateCount);
      final double cx = trackCenterOffsetX(gz);
      final double swing =
          (i.isEven ? -1.0 : 1.0) * (halfW * 0.28);
      slalomGates.add(
        SkiSlalomGate3D(
          id: i + 1,
          centerX: cx + swing,
          z: gz,
          halfWidth: track == SkiTrackId.greenBlossomValley
              ? 4.6
              : (track == SkiTrackId.blueAsnieresForest ? 4.0 : 3.5),
          isGoldRed: i.isEven,
        ),
      );
    }

    // 7. Blossom 3D Flowers (`35`, `50`, `70`) along carving lines & high above Jump Ramps!
    int blossomId = 1;
    for (final SkiJumpRamp3D ramp in jumpRamps) {
      for (int arc = 0; arc < 3 && blossomId <= track.blossomCount; arc++) {
        final double dz = 5.0 + arc * 4.8;
        final double bz = ramp.z + dz;
        final double arcY = 2.4 + math.sin((arc + 1) * 0.85) * 2.2;
        blossoms.add(
          SkiBlossomCollectible3D(
            id: blossomId++,
            x: ramp.x + (bz - ramp.z) * 0.05,
            y: arcY,
            z: bz,
            isStarGold: arc == 1 || track == SkiTrackId.blackVendomePeaks,
            points: arc == 1 ? 150 : 80,
            phaseOffset: blossomId * 0.55,
          ),
        );
      }
    }

    final int remainingBlossoms = track.blossomCount - blossoms.length;
    for (int i = 0; i < remainingBlossoms; i++) {
      final double bz = 28.0 + ((length - 70.0) * i / math.max(1, remainingBlossoms));
      final double cx = trackCenterOffsetX(bz);
      final double ribbonOffset = math.sin(bz * 0.048) * (halfW * 0.34);
      final bool starGold =
          (track == SkiTrackId.blackVendomePeaks && i % 3 == 0) || (i % 7 == 0);
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
          edition: VivienneSkiEdition.neoBlossom,
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
          edition: VivienneSkiEdition.neoBlossom,
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
          edition: VivienneSkiEdition.neoBlossom,
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
