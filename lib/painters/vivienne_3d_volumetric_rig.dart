import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../engine/ski_game_engine.dart';
import '../models/ski_models.dart';

// =============================================================================
// 1. 3D Linear Algebra Primitives (Strict Sound Null Safety, Zero Dynamic)
// =============================================================================

@immutable
class Vec3 {
  const Vec3(this.x, this.y, this.z);

  static const Vec3 zero = Vec3(0.0, 0.0, 0.0);
  static const Vec3 unitX = Vec3(1.0, 0.0, 0.0);
  static const Vec3 unitY = Vec3(0.0, 1.0, 0.0);
  static const Vec3 unitZ = Vec3(0.0, 0.0, 1.0);

  final double x;
  final double y;
  final double z;

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator -() => Vec3(-x, -y, -z);
  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);

  double dot(Vec3 o) => x * o.x + y * o.y + z * o.z;

  Vec3 cross(Vec3 o) => Vec3(
        y * o.z - z * o.y,
        z * o.x - x * o.z,
        x * o.y - y * o.x,
      );

  double get lengthSq => x * x + y * y + z * z;
  double get length => math.sqrt(lengthSq);

  Vec3 get normalized {
    final double len = length;
    if (len < 1e-8) return Vec3.unitZ;
    final double inv = 1.0 / len;
    return Vec3(x * inv, y * inv, z * inv);
  }

  static Vec3 lerp(Vec3 a, Vec3 b, double t) => Vec3(
        a.x + (b.x - a.x) * t,
        a.y + (b.y - a.y) * t,
        a.z + (b.z - a.z) * t,
      );

  double distanceTo(Vec3 o) => (this - o).length;
}

/// Column-major 4x4 affine transformation matrix for 3D skeletal hierarchy.
class Mat4 {
  Mat4._(this.m);

  factory Mat4.identity() => Mat4._(
        Float64List.fromList(<double>[
          1, 0, 0, 0, // col 0
          0, 1, 0, 0, // col 1
          0, 0, 1, 0, // col 2
          0, 0, 0, 1, // col 3
        ]),
      );

  factory Mat4.translation(double tx, double ty, double tz) => Mat4._(
        Float64List.fromList(<double>[
          1, 0, 0, 0,
          0, 1, 0, 0,
          0, 0, 1, 0,
          tx, ty, tz, 1,
        ]),
      );

  factory Mat4.scale(double sx, double sy, double sz) => Mat4._(
        Float64List.fromList(<double>[
          sx, 0, 0, 0,
          0, sy, 0, 0,
          0, 0, sz, 0,
          0, 0, 0, 1,
        ]),
      );

  factory Mat4.rotationX(double rad) {
    final double c = math.cos(rad);
    final double s = math.sin(rad);
    return Mat4._(
      Float64List.fromList(<double>[
        1, 0, 0, 0,
        0, c, s, 0,
        0, -s, c, 0,
        0, 0, 0, 1,
      ]),
    );
  }

  factory Mat4.rotationY(double rad) {
    final double c = math.cos(rad);
    final double s = math.sin(rad);
    return Mat4._(
      Float64List.fromList(<double>[
        c, 0, -s, 0,
        0, 1, 0, 0,
        s, 0, c, 0,
        0, 0, 0, 1,
      ]),
    );
  }

  factory Mat4.rotationZ(double rad) {
    final double c = math.cos(rad);
    final double s = math.sin(rad);
    return Mat4._(
      Float64List.fromList(<double>[
        c, s, 0, 0,
        -s, c, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
      ]),
    );
  }

  /// Builds a local bone transform pivoting around `pivot` in rest space:
  /// `T(pivot + offset) * Rz(rz) * Ry(ry) * Rx(rx) * S(sx, sy, sz) * T(-pivot)`.
  factory Mat4.aroundPivot({
    required Vec3 pivot,
    Vec3 offset = Vec3.zero,
    double rx = 0.0,
    double ry = 0.0,
    double rz = 0.0,
    double sx = 1.0,
    double sy = 1.0,
    double sz = 1.0,
  }) {
    Mat4 res = Mat4.translation(
      pivot.x + offset.x,
      pivot.y + offset.y,
      pivot.z + offset.z,
    );
    if (rz != 0.0) res = res.multiply(Mat4.rotationZ(rz));
    if (ry != 0.0) res = res.multiply(Mat4.rotationY(ry));
    if (rx != 0.0) res = res.multiply(Mat4.rotationX(rx));
    if (sx != 1.0 || sy != 1.0 || sz != 1.0) {
      res = res.multiply(Mat4.scale(sx, sy, sz));
    }
    return res.multiply(Mat4.translation(-pivot.x, -pivot.y, -pivot.z));
  }

  final Float64List m;

  Mat4 multiply(Mat4 b) {
    final Float64List a = m;
    final Float64List o = b.m;
    final Float64List r = Float64List(16);
    for (int col = 0; col < 4; col++) {
      final int c4 = col * 4;
      final double o0 = o[c4];
      final double o1 = o[c4 + 1];
      final double o2 = o[c4 + 2];
      final double o3 = o[c4 + 3];
      r[c4] = a[0] * o0 + a[4] * o1 + a[8] * o2 + a[12] * o3;
      r[c4 + 1] = a[1] * o0 + a[5] * o1 + a[9] * o2 + a[13] * o3;
      r[c4 + 2] = a[2] * o0 + a[6] * o1 + a[10] * o2 + a[14] * o3;
      r[c4 + 3] = a[3] * o0 + a[7] * o1 + a[11] * o2 + a[15] * o3;
    }
    return Mat4._(r);
  }

  Vec3 transformPoint(Vec3 v) => Vec3(
        m[0] * v.x + m[4] * v.y + m[8] * v.z + m[12],
        m[1] * v.x + m[5] * v.y + m[9] * v.z + m[13],
        m[2] * v.x + m[6] * v.y + m[10] * v.z + m[14],
      );

  Vec3 transformNormal(Vec3 n) => Vec3(
        m[0] * n.x + m[4] * n.y + m[8] * n.z,
        m[1] * n.x + m[5] * n.y + m[9] * n.z,
        m[2] * n.x + m[6] * n.y + m[10] * n.z,
      ).normalized;

  Vec3 get translation => Vec3(m[12], m[13], m[14]);
}

// =============================================================================
// 2. 22+ Bone Articulated Hierarchy (`Vivienne_Rig` from `BLENDER_LAB`)
// =============================================================================

enum VivienneBoneId {
  root('Root', Vec3(0.0, 0.0, 0.0)),
  pelvis('Pelvis', Vec3(0.0, 0.0, 0.42)),
  spine('Spine', Vec3(0.0, 0.0, 0.56)),
  neck('Neck', Vec3(0.0, 0.0, 0.95)),
  head('Head', Vec3(0.0, -0.02, 1.35)),
  petalTop('Petal_Top', Vec3(0.0, -0.14, 1.73)),
  petalBottom('Petal_Bottom', Vec3(0.0, -0.16, 0.97)),
  petalLeft('Petal_Left', Vec3(-0.41, -0.14, 1.35)),
  petalRight('Petal_Right', Vec3(0.41, -0.14, 1.35)),
  shoulderL('Shoulder_L', Vec3(0.28, -0.10, 0.96)),
  armUpperL('Arm_Upper_L', Vec3(0.328, -0.14, 0.98)),
  armLowerL('Arm_Lower_L', Vec3(0.42, -0.16, 0.72)),
  handClaspL('Hand_Clasp_L', Vec3(0.48, -0.18, 0.48)),
  skiPoleL('Ski_Pole_L', Vec3(0.48, -0.18, 0.48)),
  speedyBagBone('Speedy_Bag_Bone', Vec3(0.50, -0.18, 0.45)),
  shoulderR('Shoulder_R', Vec3(-0.28, -0.10, 0.96)),
  armUpperR('Arm_Upper_R', Vec3(-0.328, -0.14, 0.98)),
  armLowerR('Arm_Lower_R', Vec3(-0.42, -0.16, 0.72)),
  handClaspR('Hand_Clasp_R', Vec3(-0.48, -0.18, 0.48)),
  skiPoleR('Ski_Pole_R', Vec3(-0.48, -0.18, 0.48)),
  swingTagBone('Swing_Tag_Bone', Vec3(-0.50, -0.18, 0.45)),
  legL('Leg_L', Vec3(0.134, 0.0, 0.38)),
  shinL('Shin_L', Vec3(0.134, 0.0, 0.22)),
  footL('Foot_L', Vec3(0.134, 0.0, 0.085)),
  skiL('Ski_L', Vec3(0.134, 0.0, 0.025)),
  legR('Leg_R', Vec3(-0.134, 0.0, 0.38)),
  shinR('Shin_R', Vec3(-0.134, 0.0, 0.22)),
  footR('Foot_R', Vec3(-0.134, 0.0, 0.085)),
  skiR('Ski_R', Vec3(-0.134, 0.0, 0.025)),
  bunnyBodyBone('Bunny_Body_Bone', Vec3(0.0, -0.17, 2.26)),
  bunnyEarsBone('Bunny_Ears_Bone', Vec3(0.0, -0.18, 2.45));

  const VivienneBoneId(this.blenderName, this.restPivot);

  final String blenderName;
  final Vec3 restPivot;
}

@immutable
class VivienneBoneState3D {
  const VivienneBoneState3D({
    required this.bone,
    required this.worldMatrix,
    required this.localRx,
    required this.localRy,
    required this.localRz,
    required this.localOffset,
  });

  final VivienneBoneId bone;
  final Mat4 worldMatrix;
  final double localRx;
  final double localRy;
  final double localRz;
  final Vec3 localOffset;

  Vec3 get worldPivot => worldMatrix.transformPoint(bone.restPivot);
}

enum VivienneMotionMode {
  skiRun,
  showcase360,
  podiumCelebration,
  pauseInspection,
  spectatorCheer,
}

class VivienneSkeletonPose3D {
  VivienneSkeletonPose3D._({
    required this.bones,
    required this.yawRadians,
    required this.pitchRadians,
    required this.rollRadians,
  });

  /// Evaluates the full 22+ bone skeletal pose in real time (60-120 FPS)
  /// with strict alpine parallel ski kinematics (ZERO walk cycle on downhill,
  /// showcase, podium, or spectators!).
  factory VivienneSkeletonPose3D.evaluate({
    required VivienneSkiEdition edition,
    required double timeSeconds,
    VivienneMotionMode mode = VivienneMotionMode.skiRun,
    VivienneSkiAnimState animState = VivienneSkiAnimState.glidingRearNeutral,
    VivienneSpectatorCheerStyle cheerStyle =
        VivienneSpectatorCheerStyle.jumpAndWave,
    SkiAerialTrickKind aerialTrick = SkiAerialTrickKind.none,
    bool isAirborne = false,
    double yawDegrees = 180.0,
    double pitchDegrees = 0.0,
    double rollRadians = 0.0,
    double carveTilt = 0.0,
    double trickProgress = 0.0,
    double bagPendulumRadians = 0.0,
    double squashStretchZ = 1.0,
  }) {
    final double t = timeSeconds;

    // Determine global character 3D orientation (yaw, pitch, roll)
    double finalYawRad = yawDegrees * math.pi / 180.0;
    double finalPitchRad = pitchDegrees * math.pi / 180.0;
    double finalRollRad = rollRadians;

    // Local joint rotation accumulators
    double rootTz = 0.0;
    double rootScaleZ = squashStretchZ.clamp(0.76, 1.18);
    // Volume-conserving Squash & Stretch: sx * sy * sz = 1.0
    double rootScaleXY = 1.0 / math.sqrt(rootScaleZ);

    double pelvisRx = 0.0, pelvisRy = 0.0, pelvisRz = 0.0;
    double spineRx = 0.0, spineRy = 0.0, spineRz = 0.0;
    double headRx = 0.0, headRy = 0.0, headRz = 0.0;

    double petalTopRx = 0.0, petalBottomRx = 0.0;
    double petalLeftRy = 0.0, petalRightRy = 0.0;
    double petalLeftRz = 0.0, petalRightRz = 0.0;

    double armUpLRx = 0.0, armUpLRy = 0.0, armUpLRz = 0.0;
    double armLoLRx = 0.0, armLoLRy = 0.0;
    double poleLRx = 0.0;

    double armUpRRx = 0.0, armUpRRy = 0.0, armUpRRz = 0.0;
    double armLoRRx = 0.0, armLoRRy = 0.0;
    double poleRRx = 0.0;

    double legLRx = 0.0, legLRy = 0.0, legLRz = 0.0;
    double shinLRx = 0.0;
    double footLRx = 0.0, footLRy = 0.0;

    double legRRx = 0.0, legRRy = 0.0, legRRz = 0.0;
    double shinRRx = 0.0;
    double footRRx = 0.0, footRRy = 0.0;

    double bagRx = 0.0, bagRy = 0.0, bagRz = 0.0;
    double tagRx = 0.0, tagRy = 0.0;
    double bunnyRx = 0.0, bunnyEarsRx = 0.0, bunnyEarsRy = 0.0;

    if (mode == VivienneMotionMode.spectatorCheer) {
      // =======================================================================
      // 3D BORDER SPECTATOR CHEER (`waveArms`, `jumpAndWave`, `doubleJumpCheer`)
      // STRICTLY ZERO WALK CYCLE (`legLRx == legRRx` at every instant `t`!)
      // =======================================================================
      final double w = t * 4.8;
      double parallelKnee = 0.14;

      switch (cheerStyle) {
        case VivienneSpectatorCheerStyle.waveArms:
          // Standing on parallel feet with gentle rhythmic knee bounce & wide V-arm waving!
          final double bounce = 0.5 + 0.5 * math.sin(w);
          rootTz = math.max(0.0, math.sin(w)) * 0.035;
          parallelKnee = 0.12 + (1.0 - bounce) * 0.12;

          final double wave = math.sin(w * 1.35);
          armUpLRy = -2.18 + wave * 0.36;
          armUpRRy = 2.18 + wave * 0.36;
          armUpLRx = -0.18 + math.cos(w * 1.35) * 0.08;
          armUpRRx = -0.18 - math.cos(w * 1.35) * 0.08;
          armLoLRy = -0.22 + wave * 0.24;
          armLoRRy = 0.22 + wave * 0.24;
          armLoLRx = -0.24;
          armLoRRx = -0.24;

          pelvisRy = wave * 0.08;
          spineRz = wave * 0.12;
          headRy = wave * 0.14;
          headRz = math.cos(w * 0.7) * 0.10;
        case VivienneSpectatorCheerStyle.jumpAndWave:
          // Joyful vertical two-footed jumps (`rootTz > 0`) + high V-arms waving!
          final double jumpWave = math.sin(w);
          final double airPhase = math.max(0.0, jumpWave);
          final double crouchPhase = math.max(0.0, -jumpWave);
          rootTz = airPhase * 0.22;
          rootScaleZ = (1.0 + airPhase * 0.07 - crouchPhase * 0.08).clamp(0.86, 1.12);
          rootScaleXY = 1.0 / math.sqrt(rootScaleZ);
          parallelKnee = 0.14 + crouchPhase * 0.42 - airPhase * 0.06;

          final double wave = math.sin(w * 1.6);
          armUpLRy = -1.75 - airPhase * 0.58 + wave * 0.24;
          armUpRRy = 1.75 + airPhase * 0.58 + wave * 0.24;
          armUpLRx = -0.22;
          armUpRRx = -0.22;
          armLoLRy = -0.20 + wave * 0.18;
          armLoRRy = 0.20 + wave * 0.18;
          armLoLRx = -0.26;
          armLoRRx = -0.26;

          spineRx = airPhase * 0.10 - crouchPhase * 0.10;
          headRx = airPhase * 0.08;
          headRy = wave * 0.10;
        case VivienneSpectatorCheerStyle.doubleJumpCheer:
          // Energetic double two-footed hops + rhythmic overhead applause / cheers!
          final double hopFast = math.sin(w * 1.45).abs();
          final double cadence = 0.5 + 0.5 * math.sin(w * 0.725);
          rootTz = hopFast * (0.08 + 0.12 * cadence);
          parallelKnee = 0.15 + (1.0 - hopFast) * 0.28;

          final double clap = math.sin(w * 2.1);
          armUpLRy = -1.96 - clap * 0.34;
          armUpRRy = 1.96 + clap * 0.34;
          armUpLRx = -0.34 - clap * 0.12;
          armUpRRx = -0.34 - clap * 0.12;
          armLoLRy = 0.16 + clap * 0.26;
          armLoRRy = -0.16 - clap * 0.26;
          armLoLRx = -0.38;
          armLoRRx = -0.38;

          spineRx = 0.06;
          headRz = math.sin(w * 1.05) * 0.14;
          headRx = 0.06 + hopFast * 0.06;
      }

      // Strictly symmetric two-footed stance & jump flexion (ZERO walk cycle!)
      legLRx = -parallelKnee;
      legRRx = -parallelKnee;
      shinLRx = parallelKnee * 1.48;
      shinRRx = parallelKnee * 1.48;
      footLRx = -(legLRx + shinLRx) * 0.42;
      footRRx = -(legRRx + shinRRx) * 0.42;
      legLRy = -0.08;
      legRRy = 0.08;

      // Festive 4-petal bloom & accessory bounce
      petalTopRx = -0.18 - math.sin(w * 1.5) * 0.09;
      petalBottomRx = -0.22 - math.cos(w * 1.5) * 0.08;
      petalLeftRy = -0.18 - math.sin(w * 1.5 + 0.8) * 0.09;
      petalRightRy = 0.18 + math.sin(w * 1.5 + 1.6) * 0.09;

      bagRy = -0.28 - math.sin(w * 1.5) * 0.24;
      bagRx = math.cos(w * 1.2) * 0.18;
      tagRy = 0.26 + math.cos(w * 1.6) * 0.22;
      bunnyRx = math.sin(w * 1.8) * 0.08;
      bunnyEarsRx = -0.18 + math.sin(w * 2.2) * 0.24;
    } else if (mode == VivienneMotionMode.showcase360 ||
        mode == VivienneMotionMode.pauseInspection) {
      // Lively 3D studio showcase & pause inspection: ZERO walk cycle (`stride = 0`),
      // joined/parallel feet with gentle two-footed bounce + V-arm wave + petal bloom!
      final double w = t * 4.0;
      final double hopRaw = math.sin(t * 2.6);
      final double hopUp = math.max(0.0, hopRaw);
      final double hopCrouch = math.max(0.0, -hopRaw);
      rootTz = mode == VivienneMotionMode.pauseInspection ? 0.02 : hopUp * 0.055;

      final double parallelKnee = mode == VivienneMotionMode.pauseInspection
          ? 0.20
          : (0.14 + hopCrouch * 0.22 - hopUp * 0.05);
      legLRx = -parallelKnee;
      legRRx = -parallelKnee;
      shinLRx = parallelKnee * 1.45;
      shinRRx = parallelKnee * 1.45;
      footLRx = -(legLRx + shinLRx) * 0.42;
      footRRx = -(legRRx + shinRRx) * 0.42;
      legLRy = -0.08;
      legRRy = 0.08;

      pelvisRz = math.sin(w * 0.5) * 0.06;
      spineRz = -pelvisRz * 0.85;
      headRy = math.sin(w * 0.5) * 0.10;
      headRz = math.cos(w * 0.5) * 0.12;
      headRx = math.sin(w) * 0.05;

      // Joyful celebratory V-arms wave (no walk arm swing!)
      final double vLift = mode == VivienneMotionMode.pauseInspection
          ? 0.72
          : (0.36 + 0.54 * (0.5 + 0.5 * hopRaw));
      final double waveSway = math.sin(w * 1.25) * 0.16;
      armUpLRy = -0.36 - vLift * 1.68 + waveSway;
      armUpRRy = 0.36 + vLift * 1.68 + waveSway;
      armUpLRx = -0.18 - vLift * 0.16;
      armUpRRx = -0.18 - vLift * 0.16;
      armLoLRx = -0.34 - math.cos(w * 1.25) * 0.10;
      armLoRRx = -0.34 - math.cos(w * 1.25) * 0.10;
      poleLRx = 0.30;
      poleRRx = 0.30;

      // Expressive 4-petal bloom & wave (Petal_Bottom rx < 0 drapes forward -Y)
      petalTopRx = -0.14 - math.sin(w * 1.3) * 0.10;
      petalBottomRx = -0.22 - math.cos(w * 1.3) * 0.08;
      petalLeftRy = -0.14 - math.sin(w * 1.3 + 0.9) * 0.11;
      petalRightRy = 0.14 + math.sin(w * 1.3 + 1.8) * 0.11;

      bagRy = -0.22 - math.sin(w * 1.4) * 0.24;
      bagRx = math.cos(w * 1.1) * 0.18;
      tagRy = 0.22 + math.cos(w * 1.8) * 0.22;
      tagRx = math.sin(w * 1.9) * 0.18;
      bunnyRx = math.sin(w * 2.0) * 0.08;
      bunnyEarsRx = -0.14 + math.sin(w * 2.4 - 0.5) * 0.22;
      bunnyEarsRy = math.cos(w * 1.2) * 0.10;
    } else if (mode == VivienneMotionMode.podiumCelebration) {
      // Triumphant Chalet Podium Celebration: two-footed victory jumps (ZERO walk cycle!) & V-arms
      final double w = t * 4.8;
      final double jumpSine = math.sin(w);
      final double jumpUp = math.max(0.0, jumpSine);
      final double crouchDown = math.max(0.0, -jumpSine);
      rootTz = jumpUp * 0.11;
      rootScaleZ = (1.0 + jumpUp * 0.05 - crouchDown * 0.06).clamp(0.88, 1.10);
      rootScaleXY = 1.0 / math.sqrt(rootScaleZ);

      pelvisRz = math.sin(w * 0.5) * 0.10;
      spineRx = 0.08 * jumpUp - 0.06 * crouchDown;
      headRz = math.sin(w * 0.5) * 0.15;
      headRy = math.cos(w * 0.5) * 0.08;

      final double wave = math.sin(w * 1.6) * 0.20;
      armUpLRy = -2.24 + wave;
      armUpRRy = 2.24 + wave;
      armUpLRx = -0.22;
      armUpRRx = -0.22;
      armLoLRy = -0.22 + wave * 0.7;
      armLoRRy = 0.22 + wave * 0.7;

      final double symKnee = 0.15 + crouchDown * 0.36 - jumpUp * 0.07;
      legLRx = -symKnee;
      legRRx = -symKnee;
      legLRy = -0.10;
      legRRy = 0.10;
      shinLRx = symKnee * 1.48;
      shinRRx = symKnee * 1.48;
      footLRx = -(legLRx + shinLRx) * 0.40;
      footRRx = -(legRRx + shinRRx) * 0.40;

      petalTopRx = -0.20 - math.sin(w * 2.0) * 0.08;
      petalBottomRx = -0.24 - math.cos(w * 2.0) * 0.08;
      petalLeftRy = -0.20 - math.sin(w * 2.0) * 0.08;
      petalRightRy = 0.20 + math.sin(w * 2.0) * 0.08;

      bagRy = -0.32 - math.sin(w * 1.8) * 0.26;
      bunnyEarsRx = -0.16 + math.sin(w * 2.4) * 0.24;
    } else if (isAirborne && aerialTrick == SkiAerialTrickKind.saut360) {
      // =======================================================================
      // SAUT 360°: True 360° 3D vertical-axis spin (NEVER horizontally squished!),
      // high celebratory V-arms, athletic parallel tucked skis, blooming petals!
      // =======================================================================
      final double spinPhase = trickProgress * math.pi * 6.0 + t * 7.5;
      rootScaleZ = 1.06;
      rootScaleXY = 1.0 / math.sqrt(rootScaleZ);

      final double airTuck = 0.28 + 0.10 * math.sin(trickProgress * math.pi);
      legLRx = -airTuck;
      legRRx = -airTuck;
      legLRy = -0.12;
      legRRy = 0.12;
      shinLRx = airTuck * 1.45;
      shinRRx = airTuck * 1.45;
      footLRx = -0.12;
      footRRx = -0.12;

      // Both arms raised high in a triumphant 3D V!
      armUpLRy = -2.32 - math.sin(spinPhase) * 0.15;
      armUpRRy = 2.32 + math.cos(spinPhase) * 0.15;
      armUpLRx = -0.24 + math.cos(spinPhase) * 0.10;
      armUpRRx = -0.24 + math.cos(spinPhase) * 0.10;
      armLoLRy = -0.24;
      armLoRRy = 0.24;
      armLoLRx = -0.20 + math.sin(spinPhase * 1.3) * 0.12;
      armLoRRx = -0.20 + math.sin(spinPhase * 1.3) * 0.12;
      poleLRx = 0.42;
      poleRRx = 0.42;

      pelvisRz = math.sin(spinPhase) * 0.10;
      spineRx = 0.08;
      headRx = 0.06;
      headRy = math.sin(spinPhase * 0.5) * 0.10;

      // Full 3D corolla bloom in midair
      petalTopRx = -0.24 - math.sin(spinPhase) * 0.08;
      petalBottomRx = -0.26 - math.cos(spinPhase) * 0.08;
      petalLeftRy = -0.24 - math.sin(spinPhase + 0.8) * 0.08;
      petalRightRy = 0.24 + math.sin(spinPhase + 1.6) * 0.08;

      bagRy = -0.44 - math.sin(spinPhase) * 0.22;
      bagRx = -0.16 + math.cos(spinPhase) * 0.20;
      tagRy = 0.44 + math.cos(spinPhase) * 0.20;
      bunnyEarsRx = -0.24 + math.sin(spinPhase * 1.5) * 0.24;
    } else if (isAirborne && aerialTrick == SkiAerialTrickKind.sautPerilleux) {
      // =======================================================================
      // SAUT PÉRILLEUX: True 3D Pitch Backflip (0° -> -360° around X axis)
      // + 28° 3D perspective yaw with parallel tucked knees & skis!
      // =======================================================================
      final double flipWave = trickProgress * math.pi * 4.0 + t * 6.0;
      finalPitchRad = -finalPitchRad;
      finalYawRad += 28.0 * math.pi / 180.0;

      final double tuck = math.sin(trickProgress * math.pi);
      final double symFlipKnee = 0.26 + 0.44 * tuck;
      legLRx = -symFlipKnee;
      legRRx = -symFlipKnee;
      legLRy = -0.13;
      legRRy = 0.13;
      shinLRx = 0.28 + 0.56 * tuck;
      shinRRx = 0.28 + 0.56 * tuck;
      footLRx = -0.14;
      footRRx = -0.14;

      // Dynamic wide aero-stabilizer V arms in 3D
      armUpLRy = -1.96 - 0.28 * tuck;
      armUpRRy = 1.96 + 0.28 * tuck;
      armUpLRx = -0.28;
      armUpRRx = -0.28;
      armLoLRx = -0.34;
      armLoRRx = -0.34;
      poleLRx = 0.45;
      poleRRx = 0.45;

      spineRx = 0.14 * tuck;
      headRx = 0.20 * tuck;

      petalTopRx = -0.26;
      petalBottomRx = -0.26;
      petalLeftRy = -0.24;
      petalRightRy = 0.24;

      bagRy = -0.48;
      bagRx = -0.28 + math.sin(flipWave) * 0.22;
      tagRy = 0.48;
      tagRx = 0.35;
      bunnyEarsRx = -0.36;
    } else if (animState == VivienneSkiAnimState.mogulAbsorptionSquash ||
        animState == VivienneSkiAnimState.landingImpact) {
      // Deep 3D volume-conserving Squash (`sz = 0.80`, deep parallel knee flexion, tucked arms)
      rootScaleZ = 0.80;
      rootScaleXY = 1.0 / math.sqrt(rootScaleZ);
      rootTz = -0.08;

      legLRx = -0.66;
      legRRx = -0.66;
      legLRy = -0.10;
      legRRy = 0.10;
      shinLRx = 0.86;
      shinRRx = 0.86;
      footLRx = -0.20;
      footRRx = -0.20;

      pelvisRx = -0.22;
      spineRx = -0.24;
      headRx = 0.22;

      // Arms swept out & back (+Y) for landing balance
      armUpLRy = -1.08;
      armUpRRy = 1.08;
      armUpLRx = 0.46;
      armUpRRx = 0.46;
      armLoLRx = -0.50;
      armLoRRx = -0.50;
      poleLRx = 0.35;
      poleRRx = 0.35;

      petalTopRx = 0.22;
      petalBottomRx = -0.34;
      petalLeftRy = 0.20;
      petalRightRy = -0.20;
      bagRy = -0.52;
      bunnyEarsRx = 0.32;
    } else if (isAirborne ||
        animState == VivienneSkiAnimState.rampLaunchStretch ||
        animState == VivienneSkiAnimState.airborneCelebration) {
      // Ramp Takeoff Stretch & Big Air Celebration (parallel ski posture, ZERO scissor/walk!)
      final double airWave = t * 6.0;
      rootScaleZ = 1.12;
      rootScaleXY = 1.0 / math.sqrt(rootScaleZ);

      final double airParallelFlex = 0.20 + 0.05 * math.cos(airWave);
      legLRx = -airParallelFlex;
      legRRx = -airParallelFlex;
      legLRy = -0.10;
      legRRy = 0.10;
      shinLRx = airParallelFlex * 1.35;
      shinRRx = airParallelFlex * 1.35;
      footLRx = -0.08;
      footRRx = -0.08;

      armUpLRy = -2.22 - math.sin(airWave) * 0.14;
      armUpRRy = 2.22 + math.sin(airWave) * 0.14;
      armUpLRx = -0.20;
      armUpRRx = -0.20;
      armLoLRx = -0.24;
      armLoRRx = -0.24;
      poleLRx = 0.48;
      poleRRx = 0.48;

      petalTopRx = -0.22;
      petalBottomRx = -0.24;
      petalLeftRy = -0.22;
      petalRightRy = 0.22;
      bagRy = -0.42;
      bunnyEarsRx = -0.28;
    } else {
      // =======================================================================
      // DOWNHILL SCHUSS & DYNAMIC 3D CARVING (`glidingRearNeutral`, `carvingLeft`, `carvingRight`)
      // STRICTLY ZERO WALK CYCLE (`rhythmLeg = 0.0`, `poleSwing = 0.0`):
      // Both skis & legs stay parallel longitudinally with in-phase ski suspension
      // and aerodynamic tucked ski arms!
      // =======================================================================
      final double carve = carveTilt.clamp(-1.0, 1.0);
      final double glidePhase = t * 7.2;

      // 1. True 3D Carving Yaw (`yaw = 180° - carve * 36°`)
      finalYawRad -= carve * (36.0 * math.pi / 180.0);
      finalRollRad = rollRadians * 0.85;

      // 2. Parallel In-Phase Ski Suspension (identical phase on both legs — NEVER opposing!)
      final double suspWave = math.sin(glidePhase);
      rootTz = -0.038 + suspWave * 0.032 - carve.abs() * 0.04;

      // Static edge angulation flexes inside knee higher vertically without longitudinal walk!
      final double rightInside = math.max(0.0, carve);
      final double leftInside = math.max(0.0, -carve);
      final double parallelKneeSusp = 0.26 + suspWave * 0.075;

      legLRx = -parallelKneeSusp - leftInside * 0.24;
      shinLRx = parallelKneeSusp * 1.42 + leftInside * 0.28;
      footLRx = -0.11 - leftInside * 0.06 - suspWave * 0.03;
      footLRy = -carve * 0.24;
      legLRy = -0.06 + carve * 0.09;

      legRRx = -parallelKneeSusp - rightInside * 0.24;
      shinRRx = parallelKneeSusp * 1.42 + rightInside * 0.28;
      footRRx = -0.11 - rightInside * 0.06 - suspWave * 0.03;
      footRRy = -carve * 0.24;
      legRRy = 0.06 + carve * 0.09;

      // Hip/Spine counter-rotation (`angulation`) so upper body faces down the fall-line!
      pelvisRz = -carve * 0.22;
      spineRz = carve * 0.28;
      spineRx = -0.16 - suspWave * 0.045;
      headRy = -carve * 0.22;
      headRz = carve * 0.16;
      headRx = 0.12 + suspWave * 0.045;

      // 3. Aerodynamic Downhill / Carving Arm Tuck (elbows forward/outward, poles streamlined back,
      // static lateral balance opening in turns, in-phase bump absorption — ZERO walk swing!)
      final double aeroSusp = suspWave * 0.06;
      armUpLRy = -0.62 - leftInside * 0.28 - rightInside * 0.10 - aeroSusp;
      armUpRRy = 0.62 + rightInside * 0.28 + leftInside * 0.10 + aeroSusp;
      armUpLRx = -0.42 + carve * 0.24 - aeroSusp;
      armUpRRx = -0.42 - carve * 0.24 - aeroSusp;
      armLoLRx = -0.58 - aeroSusp * 0.75;
      armLoRRx = -0.58 - aeroSusp * 0.75;
      armLoLRy = 0.16;
      armLoRRy = -0.16;
      poleLRx = 0.68 + aeroSusp * 0.55;
      poleRRx = 0.68 + aeroSusp * 0.55;

      // 4. Staggered aerodynamic wind flutter on the 4 petals + accessory pendulum!
      petalTopRx = -0.16 - math.sin(glidePhase * 1.4) * 0.09;
      petalBottomRx = -0.22 - math.cos(glidePhase * 1.4 + 0.8) * 0.08;
      petalLeftRy =
          -0.16 - math.sin(glidePhase * 1.4 + 1.6) * 0.10 + carve * 0.12;
      petalRightRy =
          0.16 + math.sin(glidePhase * 1.4 + 2.4) * 0.10 + carve * 0.12;

      bagRy = -0.28 -
          bagPendulumRadians * 0.85 -
          math.sin(glidePhase * 1.2) * 0.18 +
          carve * 0.32;
      bagRx = 0.18 + math.cos(glidePhase) * 0.16;
      tagRy =
          0.26 + bagPendulumRadians * 0.70 + math.cos(glidePhase * 1.5) * 0.22;
      tagRx = 0.20 + math.sin(glidePhase * 1.5) * 0.18;
      bunnyRx = -0.08 + math.sin(glidePhase * 1.6) * 0.08;
      bunnyEarsRx = -0.22 + math.sin(glidePhase * 2.0 - 0.6) * 0.22;
      bunnyEarsRy = carve * 0.24;
    }

    // =========================================================================
    // Forward Kinematics Hierarchy Assembly (Root -> 22+ Bones)
    // =========================================================================
    final Map<VivienneBoneId, VivienneBoneState3D> map =
        <VivienneBoneId, VivienneBoneState3D>{};

    VivienneBoneState3D buildBone(
      VivienneBoneId id,
      VivienneBoneState3D? parent, {
      Vec3 offset = Vec3.zero,
      double rx = 0.0,
      double ry = 0.0,
      double rz = 0.0,
      double sx = 1.0,
      double sy = 1.0,
      double sz = 1.0,
    }) {
      final Mat4 local = Mat4.aroundPivot(
        pivot: id.restPivot,
        offset: offset,
        rx: rx,
        ry: ry,
        rz: rz,
        sx: sx,
        sy: sy,
        sz: sz,
      );
      final Mat4 world =
          parent == null ? local : parent.worldMatrix.multiply(local);
      final VivienneBoneState3D state = VivienneBoneState3D(
        bone: id,
        worldMatrix: world,
        localRx: rx,
        localRy: ry,
        localRz: rz,
        localOffset: offset,
      );
      map[id] = state;
      return state;
    }

    // Global 3D Root Orientation:
    // 1) Scale around soles (Z = 0) + vertical hop `rootTz`
    // 2) Pitch around center-of-mass `(0, 0, 1.05)` (authentic 3D backflip!)
    // 3) Roll around `(0, 0, 0.25)` + Yaw around `(0, 0, 0)`
    Mat4 rootWorld = Mat4.translation(0.0, 0.0, rootTz)
        .multiply(Mat4.rotationZ(finalYawRad))
        .multiply(
          Mat4.aroundPivot(
            pivot: const Vec3(0.0, 0.0, 0.20),
            ry: finalRollRad,
          ),
        )
        .multiply(
          Mat4.aroundPivot(
            pivot: const Vec3(0.0, 0.0, 1.05),
            rx: finalPitchRad,
          ),
        )
        .multiply(Mat4.scale(rootScaleXY, rootScaleXY, rootScaleZ));

    final VivienneBoneState3D rootState = VivienneBoneState3D(
      bone: VivienneBoneId.root,
      worldMatrix: rootWorld,
      localRx: finalPitchRad,
      localRy: finalRollRad,
      localRz: finalYawRad,
      localOffset: Vec3(0.0, 0.0, rootTz),
    );
    map[VivienneBoneId.root] = rootState;

    final VivienneBoneState3D pelvis = buildBone(
      VivienneBoneId.pelvis,
      rootState,
      rx: pelvisRx,
      ry: pelvisRy,
      rz: pelvisRz,
    );
    final VivienneBoneState3D spine = buildBone(
      VivienneBoneId.spine,
      pelvis,
      rx: spineRx,
      ry: spineRy,
      rz: spineRz,
    );
    final VivienneBoneState3D neck = buildBone(
      VivienneBoneId.neck,
      spine,
      rx: headRx * 0.35,
      ry: headRy * 0.35,
      rz: headRz * 0.35,
    );
    final VivienneBoneState3D head = buildBone(
      VivienneBoneId.head,
      neck,
      rx: headRx * 0.65,
      ry: headRy * 0.65,
      rz: headRz * 0.65,
    );

    // 4 Volumetric Corolla Petals parented to Head
    final VivienneBoneState3D petalTop = buildBone(
      VivienneBoneId.petalTop,
      head,
      rx: petalTopRx,
    );
    buildBone(VivienneBoneId.petalBottom, head, rx: petalBottomRx);
    buildBone(
      VivienneBoneId.petalLeft,
      head,
      ry: petalLeftRy,
      rz: petalLeftRz,
    );
    buildBone(
      VivienneBoneId.petalRight,
      head,
      ry: petalRightRy,
      rz: petalRightRz,
    );

    // Wonderland Bunny + Ears parented to Petal_Top
    final VivienneBoneState3D bunnyBody = buildBone(
      VivienneBoneId.bunnyBodyBone,
      petalTop,
      rx: bunnyRx,
    );
    buildBone(
      VivienneBoneId.bunnyEarsBone,
      bunnyBody,
      rx: bunnyEarsRx,
      ry: bunnyEarsRy,
    );

    // Keep Heart Balloon rising buoyantly upward (+Z) & Speedy Bag hanging naturally under gravity
    // even when Arm_Upper_L rotates high into a celebratory V!
    final double armTotalLiftRy = armUpLRy + armLoLRy;
    final double gravityCompRy = switch (edition) {
      VivienneSkiEdition.wonderland => -armTotalLiftRy * 0.90 - 0.52,
      VivienneSkiEdition.speedyV03 => -armTotalLiftRy * 0.68,
      VivienneSkiEdition.giantDenim => -armTotalLiftRy * 0.35,
    };

    // Left Arm + Ski Pole + Speedy Bag / Heart Balloon / Skateboard
    final VivienneBoneState3D shoulderL =
        buildBone(VivienneBoneId.shoulderL, spine);
    final VivienneBoneState3D armUpperL = buildBone(
      VivienneBoneId.armUpperL,
      shoulderL,
      rx: armUpLRx,
      ry: armUpLRy,
      rz: armUpLRz,
    );
    final VivienneBoneState3D armLowerL = buildBone(
      VivienneBoneId.armLowerL,
      armUpperL,
      rx: armLoLRx,
      ry: armLoLRy,
    );
    final VivienneBoneState3D handL =
        buildBone(VivienneBoneId.handClaspL, armLowerL);
    buildBone(VivienneBoneId.skiPoleL, handL, rx: poleLRx);
    buildBone(
      VivienneBoneId.speedyBagBone,
      handL,
      rx: bagRx - armUpLRx * 0.55,
      ry: gravityCompRy + bagRy * 0.45,
      rz: bagRz,
    );

    // Right Arm + Ski Pole + Giant Denim Swing Tag
    final VivienneBoneState3D shoulderR =
        buildBone(VivienneBoneId.shoulderR, spine);
    final VivienneBoneState3D armUpperR = buildBone(
      VivienneBoneId.armUpperR,
      shoulderR,
      rx: armUpRRx,
      ry: armUpRRy,
      rz: armUpRRz,
    );
    final VivienneBoneState3D armLowerR = buildBone(
      VivienneBoneId.armLowerR,
      armUpperR,
      rx: armLoRRx,
      ry: armLoRRy,
    );
    final VivienneBoneState3D handR =
        buildBone(VivienneBoneId.handClaspR, armLowerR);
    buildBone(VivienneBoneId.skiPoleR, handR, rx: poleRRx);
    buildBone(
      VivienneBoneId.swingTagBone,
      handR,
      rx: tagRx,
      ry: tagRy,
    );

    // Left Leg -> Shin -> Foot/Sneaker -> Parabolic Ski
    final VivienneBoneState3D legL = buildBone(
      VivienneBoneId.legL,
      pelvis,
      rx: legLRx,
      ry: legLRy,
      rz: legLRz,
    );
    final VivienneBoneState3D shinL =
        buildBone(VivienneBoneId.shinL, legL, rx: shinLRx);
    final VivienneBoneState3D footL = buildBone(
      VivienneBoneId.footL,
      shinL,
      rx: footLRx,
      ry: footLRy,
    );
    buildBone(VivienneBoneId.skiL, footL);

    // Right Leg -> Shin -> Foot/Sneaker -> Parabolic Ski
    final VivienneBoneState3D legR = buildBone(
      VivienneBoneId.legR,
      pelvis,
      rx: legRRx,
      ry: legRRy,
      rz: legRRz,
    );
    final VivienneBoneState3D shinR =
        buildBone(VivienneBoneId.shinR, legR, rx: shinRRx);
    final VivienneBoneState3D footR = buildBone(
      VivienneBoneId.footR,
      shinR,
      rx: footRRx,
      ry: footRRy,
    );
    buildBone(VivienneBoneId.skiR, footR);

    return VivienneSkeletonPose3D._(
      bones: map,
      yawRadians: finalYawRad,
      pitchRadians: finalPitchRad,
      rollRadians: finalRollRad,
    );
  }

  final Map<VivienneBoneId, VivienneBoneState3D> bones;
  final double yawRadians;
  final double pitchRadians;
  final double rollRadians;

  VivienneBoneState3D operator [](VivienneBoneId id) => bones[id]!;

  /// Lookup by canonical `BLENDER_LAB` bone name (`'Leg_L'`, `'Foot_L'`, `'Arm_Upper_L'`,
  /// `'Petal_Top'`, `'Speedy_Bag_Bone'`, `'Thigh_L'`, `'Heart_Balloon_Bone'`, `'Skateboard_Bone'`, etc.).
  VivienneBoneState3D? boneByName(String name) {
    for (final VivienneBoneId id in VivienneBoneId.values) {
      if (id.blenderName == name) return bones[id];
    }
    switch (name) {
      case 'Thigh_L':
        return bones[VivienneBoneId.legL];
      case 'Thigh_R':
        return bones[VivienneBoneId.legR];
      case 'Heart_Balloon_Bone':
      case 'Skateboard_Bone':
        return bones[VivienneBoneId.speedyBagBone];
      default:
        return null;
    }
  }
}

// =============================================================================
// 3. 3D Volumetric Mesh Representation & Procedural `BLENDER_LAB` Builders
// =============================================================================

@immutable
class _MatSpec3D {
  const _MatSpec3D(
    this.color, {
    this.specStrength = 0.24,
    this.shininess = 14.0,
    this.outlineScale = 1.0,
  });

  final Color color;
  final double specStrength;
  final double shininess;
  final double outlineScale;
}

class _RigVertex3D {
  const _RigVertex3D({
    required this.bone,
    required this.pos,
    required this.normal,
    required this.outlineNormal,
    required this.mat,
    required this.isSkiGear,
  });

  final VivienneBoneId bone;
  final Vec3 pos;
  final Vec3 normal;
  final Vec3 outlineNormal;
  final _MatSpec3D mat;
  final bool isSkiGear;
}

class _RigTri3D {
  const _RigTri3D(
    this.i0,
    this.i1,
    this.i2, {
    required this.isSkiGear,
    required this.castOutline,
  });

  final int i0;
  final int i1;
  final int i2;
  final bool isSkiGear;
  final bool castOutline;
}

class _EditionVolumetricMesh {
  const _EditionVolumetricMesh({
    required this.vertices,
    required this.triangles,
  });

  final List<_RigVertex3D> vertices;
  final List<_RigTri3D> triangles;
}

class _RigMeshBuilder {
  final List<_RigVertex3D> _verts = <_RigVertex3D>[];
  final List<_RigTri3D> _tris = <_RigTri3D>[];

  int _addV(
    VivienneBoneId bone,
    Vec3 pos,
    Vec3 normal,
    _MatSpec3D mat, {
    Vec3? outlineNormal,
    bool isSkiGear = false,
  }) {
    final int idx = _verts.length;
    final Vec3 n = normal.normalized;
    _verts.add(
      _RigVertex3D(
        bone: bone,
        pos: pos,
        normal: n,
        outlineNormal: (outlineNormal ?? n).normalized,
        mat: mat,
        isSkiGear: isSkiGear,
      ),
    );
    return idx;
  }

  /// Adds a triangle guaranteed to have outward CCW winding matching the vertex normals.
  void _addTri(
    int a,
    int b,
    int c, {
    bool isSkiGear = false,
    bool castOutline = true,
  }) {
    final Vec3 pa = _verts[a].pos;
    final Vec3 pb = _verts[b].pos;
    final Vec3 pc = _verts[c].pos;
    final Vec3 geomN = (pb - pa).cross(pc - pa);
    if (geomN.lengthSq < 1e-12) return;
    final Vec3 avgN = _verts[a].normal + _verts[b].normal + _verts[c].normal;
    if (geomN.dot(avgN) >= 0.0) {
      _tris.add(
        _RigTri3D(a, b, c, isSkiGear: isSkiGear, castOutline: castOutline),
      );
    } else {
      _tris.add(
        _RigTri3D(a, c, b, isSkiGear: isSkiGear, castOutline: castOutline),
      );
    }
  }

  void _addQuad(
    int a,
    int b,
    int c,
    int d, {
    bool isSkiGear = false,
    bool castOutline = true,
  }) {
    _addTri(a, b, c, isSkiGear: isSkiGear, castOutline: castOutline);
    _addTri(a, c, d, isSkiGear: isSkiGear, castOutline: castOutline);
  }

  static Color _modulateColor(Color base, double factor) {
    final int a = (base.a * 255.0).round().clamp(0, 255);
    final int r = (base.r * 255.0 * factor).round().clamp(0, 255);
    final int g = (base.g * 255.0 * factor).round().clamp(0, 255);
    final int b = (base.b * 255.0 * factor).round().clamp(0, 255);
    return Color.fromARGB(a, r, g, b);
  }

  /// Closed 3D UV Ellipsoid with optional subtle wood-grain modulation.
  void addEllipsoid({
    required VivienneBoneId bone,
    required Vec3 center,
    required Vec3 radii,
    required _MatSpec3D mat,
    int rings = 10,
    int segs = 18,
    bool woodGrain = false,
    bool isSkiGear = false,
    bool castOutline = true,
  }) {
    final List<List<int>> grid = <List<int>>[];
    for (int r = 0; r <= rings; r++) {
      final double v = r / rings;
      final double phi = (v - 0.5) * math.pi; // -pi/2 .. +pi/2
      final double cosPhi = math.cos(phi);
      final double sinPhi = math.sin(phi);
      final List<int> row = <int>[];
      for (int s = 0; s < segs; s++) {
        final double theta = (s / segs) * 2.0 * math.pi;
        final double cosT = math.cos(theta);
        final double sinT = math.sin(theta);

        final Vec3 unit = Vec3(cosPhi * cosT, cosPhi * sinT, sinPhi);
        final Vec3 pos = Vec3(
          center.x + unit.x * radii.x,
          center.y + unit.y * radii.y,
          center.z + unit.z * radii.z,
        );
        final Vec3 gradN = Vec3(
          unit.x / math.max(0.02, radii.x),
          unit.y / math.max(0.02, radii.y),
          unit.z / math.max(0.02, radii.z),
        ).normalized;

        _MatSpec3D vMat = mat;
        if (woodGrain) {
          final double grain =
              1.0 + 0.045 * math.sin(theta * 7.0 + sinPhi * 3.2);
          vMat = _MatSpec3D(
            _modulateColor(mat.color, grain),
            specStrength: mat.specStrength,
            shininess: mat.shininess,
            outlineScale: mat.outlineScale,
          );
        }
        row.add(
          _addV(
            bone,
            pos,
            gradN,
            vMat,
            outlineNormal: gradN,
            isSkiGear: isSkiGear,
          ),
        );
      }
      grid.add(row);
    }

    for (int r = 0; r < rings; r++) {
      for (int s = 0; s < segs; s++) {
        final int ns = (s + 1) % segs;
        _addQuad(
          grid[r][s],
          grid[r][ns],
          grid[r + 1][ns],
          grid[r + 1][s],
          isSkiGear: isSkiGear,
          castOutline: castOutline,
        );
      }
    }
  }

  /// Closed 3D Elliptical Cylinder / Frustum along an arbitrary local axis `(p0 -> p1)`.
  void addCappedLimb({
    required VivienneBoneId bone,
    required Vec3 p0,
    required Vec3 p1,
    required double rx0,
    required double ry0,
    required double rx1,
    required double ry1,
    required _MatSpec3D mat,
    int segs = 12,
    int stacks = 2,
    bool isSkiGear = false,
    bool castOutline = true,
  }) {
    final Vec3 axis = p1 - p0;
    final double len = axis.length;
    if (len < 1e-6) return;
    final Vec3 wDir = axis * (1.0 / len);
    final Vec3 ref = wDir.x.abs() < 0.85 ? Vec3.unitX : Vec3.unitY;
    final Vec3 uDir = ref.cross(wDir).normalized;
    final Vec3 vDir = wDir.cross(uDir).normalized;
    final Vec3 mid = (p0 + p1) * 0.5;

    final List<List<int>> rings = <List<int>>[];
    for (int st = 0; st <= stacks; st++) {
      final double t = st / stacks;
      final Vec3 c = Vec3.lerp(p0, p1, t);
      final double rx = rx0 + (rx1 - rx0) * t;
      final double ry = ry0 + (ry1 - ry0) * t;
      final List<int> row = <int>[];
      for (int s = 0; s < segs; s++) {
        final double ang = (s / segs) * 2.0 * math.pi;
        final double ca = math.cos(ang);
        final double sa = math.sin(ang);
        final Vec3 radial = (uDir * (ca * rx)) + (vDir * (sa * ry));
        final Vec3 pos = c + radial;
        final Vec3 norm =
            ((uDir * (ca / math.max(0.01, rx))) + (vDir * (sa / math.max(0.01, ry))))
                .normalized;
        final Vec3 outN = (pos - mid).normalized;
        row.add(
          _addV(
            bone,
            pos,
            norm,
            mat,
            outlineNormal: outN,
            isSkiGear: isSkiGear,
          ),
        );
      }
      rings.add(row);
    }

    for (int st = 0; st < stacks; st++) {
      for (int s = 0; s < segs; s++) {
        final int ns = (s + 1) % segs;
        _addQuad(
          rings[st][s],
          rings[st][ns],
          rings[st + 1][ns],
          rings[st + 1][s],
          isSkiGear: isSkiGear,
          castOutline: castOutline,
        );
      }
    }

    // End caps
    final int cap0 = _addV(
      bone,
      p0 - wDir * (math.min(rx0, ry0) * 0.25),
      -wDir,
      mat,
      outlineNormal: -wDir,
      isSkiGear: isSkiGear,
    );
    final int cap1 = _addV(
      bone,
      p1 + wDir * (math.min(rx1, ry1) * 0.25),
      wDir,
      mat,
      outlineNormal: wDir,
      isSkiGear: isSkiGear,
    );
    for (int s = 0; s < segs; s++) {
      final int ns = (s + 1) % segs;
      _addTri(
        cap0,
        rings[0][ns],
        rings[0][s],
        isSkiGear: isSkiGear,
        castOutline: castOutline,
      );
      _addTri(
        cap1,
        rings[stacks][s],
        rings[stacks][ns],
        isSkiGear: isSkiGear,
        castOutline: castOutline,
      );
    }
  }

  /// Closed 3D Oriented Box with independent Front/Back/Side/Top/Bottom materials
  /// (ideal for red-edged 3D leather arm straps, clasps, swing tags & bindings!).
  void addBeveledBox3D({
    required VivienneBoneId bone,
    required Vec3 center,
    required Vec3 halfExtents,
    required _MatSpec3D faceMat,
    _MatSpec3D? sideEdgeMat,
    _MatSpec3D? topBottomMat,
    Mat4? localTransform,
    bool isSkiGear = false,
    bool castOutline = true,
  }) {
    final _MatSpec3D edgeM = sideEdgeMat ?? faceMat;
    final _MatSpec3D tbM = topBottomMat ?? edgeM;

    Vec3 xfP(Vec3 p) {
      final Vec3 local = center + p;
      return localTransform == null ? local : localTransform.transformPoint(local);
    }

    Vec3 xfN(Vec3 n) =>
        localTransform == null ? n : localTransform.transformNormal(n);

    final double hx = halfExtents.x;
    final double hy = halfExtents.y;
    final double hz = halfExtents.z;

    void addFace(
      List<Vec3> corners,
      Vec3 n,
      _MatSpec3D m,
    ) {
      final Vec3 wn = xfN(n);
      final List<int> ids = corners.map((Vec3 c) {
        final Vec3 wp = xfP(c);
        final Vec3 outN = xfN(c.normalized);
        return _addV(
          bone,
          wp,
          wn,
          m,
          outlineNormal: outN,
          isSkiGear: isSkiGear,
        );
      }).toList();
      _addQuad(
        ids[0],
        ids[1],
        ids[2],
        ids[3],
        isSkiGear: isSkiGear,
        castOutline: castOutline,
      );
    }

    // Front (-Y) and Back (+Y)
    addFace(
      <Vec3>[
        Vec3(-hx, -hy, -hz),
        Vec3(hx, -hy, -hz),
        Vec3(hx, -hy, hz),
        Vec3(-hx, -hy, hz),
      ],
      const Vec3(0, -1, 0),
      faceMat,
    );
    addFace(
      <Vec3>[
        Vec3(hx, hy, -hz),
        Vec3(-hx, hy, -hz),
        Vec3(-hx, hy, hz),
        Vec3(hx, hy, hz),
      ],
      const Vec3(0, 1, 0),
      faceMat,
    );
    // Left (+X) and Right (-X) Carmine Red edges
    addFace(
      <Vec3>[
        Vec3(hx, -hy, -hz),
        Vec3(hx, hy, -hz),
        Vec3(hx, hy, hz),
        Vec3(hx, -hy, hz),
      ],
      const Vec3(1, 0, 0),
      edgeM,
    );
    addFace(
      <Vec3>[
        Vec3(-hx, hy, -hz),
        Vec3(-hx, -hy, -hz),
        Vec3(-hx, -hy, hz),
        Vec3(-hx, hy, hz),
      ],
      const Vec3(-1, 0, 0),
      edgeM,
    );
    // Top (+Z) and Bottom (-Z)
    addFace(
      <Vec3>[
        Vec3(-hx, -hy, hz),
        Vec3(hx, -hy, hz),
        Vec3(hx, hy, hz),
        Vec3(-hx, hy, hz),
      ],
      const Vec3(0, 0, 1),
      tbM,
    );
    addFace(
      <Vec3>[
        Vec3(-hx, hy, -hz),
        Vec3(hx, hy, -hz),
        Vec3(hx, -hy, -hz),
        Vec3(-hx, -hy, -hz),
      ],
      const Vec3(0, 0, -1),
      tbM,
    );
  }

  /// Adds a 3D Star/Quatrefoil relief emblem on a plane `(center, uAxis, vAxis, normal)`.
  void addStarFlowerRelief3D({
    required VivienneBoneId bone,
    required Vec3 center,
    required Vec3 uAxis,
    required Vec3 vAxis,
    required Vec3 normal,
    required double outerRadius,
    required double innerRadius,
    required double reliefDepth,
    required _MatSpec3D mat,
    bool castOutline = false,
    bool isSkiGear = false,
  }) {
    const int pts = 8;
    final int apex = _addV(
      bone,
      center + normal * reliefDepth,
      normal,
      mat,
      outlineNormal: normal,
      isSkiGear: isSkiGear,
    );
    final List<int> ring = <int>[];
    for (int i = 0; i < pts; i++) {
      final double ang = (i / pts) * 2.0 * math.pi;
      final double r = i.isEven ? outerRadius : innerRadius;
      final Vec3 radial = uAxis * (math.cos(ang) * r) + vAxis * (math.sin(ang) * r);
      final Vec3 p = center + radial + normal * (reliefDepth * 0.22);
      final Vec3 bevelN = (normal * 0.78 + radial.normalized * 0.62).normalized;
      ring.add(
        _addV(
          bone,
          p,
          bevelN,
          mat,
          outlineNormal: bevelN,
          isSkiGear: isSkiGear,
        ),
      );
    }
    for (int i = 0; i < pts; i++) {
      final int ni = (i + 1) % pts;
      _addTri(
        apex,
        ring[i],
        ring[ni],
        isSkiGear: isSkiGear,
        castOutline: castOutline,
      );
    }
  }

  /// Closed 3D Volumetric Corolla Petal matching `generate_vivienne_speedy.py`:
  /// - Domed front (`-Y`) & domed back (`+Y`) faces
  /// - Full 3D Carmine Red `#8B1E24` (or Dark Indigo `#1D3557`) perimeter beveled edge strip (`thickness = 0.072`)
  /// - Raised 3D Saddle Stitches & 3D LV Monogram Star emblems on BOTH front & back faces!
  void addVolumetricPetal3D({
    required VivienneBoneId bone,
    required Vec3 basePivot,
    required Vec3 dirAxis, // Unit direction from base toward petal tip
    required Vec3 widthAxis, // Unit lateral axis in petal plane
    required double length,
    required double maxWidth,
    required double thickness,
    required double forwardCup,
    required _MatSpec3D faceMat,
    required _MatSpec3D edgeMat,
    required _MatSpec3D stitchMat,
    required _MatSpec3D motifMat,
    required bool showLargeMonogram,
  }) {
    // Normal pointing toward Front (-Y)
    final Vec3 frontN = const Vec3(0, -1, 0);
    final int segs = 20;
    final double halfT = thickness * 0.5;

    Vec3 evalOutline2D(double u, double sideSign) {
      // Exact teardrop curve: narrow rounded base, plump upper lobe, pointed-round tip
      final double env =
          math.sin(math.pow(u.clamp(0.0, 1.0), 0.72) * math.pi).toDouble();
      final double w = maxWidth * 0.5 * (0.20 + 0.80 * env);
      final double cupY = -forwardCup * u * u; // cups gently forward (-Y)
      return basePivot +
          dirAxis * (u * length) +
          widthAxis * (sideSign * w) +
          Vec3(0.0, cupY, 0.0);
    }

    // Build closed perimeter loop (0..segs-1) around the teardrop
    final List<Vec3> perimMid = <Vec3>[];
    final List<Vec3> perimOutDir = <Vec3>[];
    for (int i = 0; i < segs; i++) {
      final double theta = (i / segs) * 2.0 * math.pi; // 0 = base, pi = tip
      final double u = 0.5 - 0.5 * math.cos(theta);
      final double side = math.sin(theta);
      final Vec3 p = evalOutline2D(u, side);
      perimMid.add(p);
    }

    final Vec3 centerMid = basePivot +
        dirAxis * (length * 0.52) +
        Vec3(0.0, -forwardCup * 0.30, 0.0);

    for (int i = 0; i < segs; i++) {
      final Vec3 prev = perimMid[(i - 1 + segs) % segs];
      final Vec3 next = perimMid[(i + 1) % segs];
      final Vec3 tang = (next - prev).normalized;
      // Outward in-plane normal perpendicular to tangent and frontN
      Vec3 out = tang.cross(frontN).normalized;
      if (out.dot(perimMid[i] - centerMid) < 0.0) {
        out = -out;
      }
      perimOutDir.add(out);
    }

    // Domed Front (-Y) & Back (+Y) surfaces with intermediate ring for lush 3D curvature
    final int frontCenter = _addV(
      bone,
      centerMid + frontN * (halfT + 0.022),
      frontN,
      faceMat,
      outlineNormal: frontN,
    );
    final int backCenter = _addV(
      bone,
      centerMid - frontN * (halfT + 0.022),
      -frontN,
      faceMat,
      outlineNormal: -frontN,
    );

    final List<int> frontMidRing = <int>[];
    final List<int> backMidRing = <int>[];
    final List<int> frontRim = <int>[];
    final List<int> backRim = <int>[];
    final List<int> edgeFront = <int>[];
    final List<int> edgeBack = <int>[];

    for (int i = 0; i < segs; i++) {
      final Vec3 pm = perimMid[i];
      final Vec3 out = perimOutDir[i];
      final Vec3 midPt = Vec3.lerp(centerMid, pm, 0.58);

      frontMidRing.add(
        _addV(
          bone,
          midPt + frontN * (halfT + 0.015),
          (frontN * 0.92 + out * 0.22).normalized,
          faceMat,
          outlineNormal: (frontN * 0.65 + out * 0.75).normalized,
        ),
      );
      backMidRing.add(
        _addV(
          bone,
          midPt - frontN * (halfT + 0.015),
          (-frontN * 0.92 + out * 0.22).normalized,
          faceMat,
          outlineNormal: (-frontN * 0.65 + out * 0.75).normalized,
        ),
      );

      final Vec3 pf = pm + frontN * halfT;
      final Vec3 pb = pm - frontN * halfT;
      final Vec3 smoothOut = (out * 0.88 + frontN * 0.18).normalized;
      final Vec3 smoothOutBack = (out * 0.88 - frontN * 0.18).normalized;

      frontRim.add(
        _addV(
          bone,
          pf,
          (frontN * 0.84 + out * 0.54).normalized,
          faceMat,
          outlineNormal: smoothOut,
        ),
      );
      backRim.add(
        _addV(
          bone,
          pb,
          (-frontN * 0.84 + out * 0.54).normalized,
          faceMat,
          outlineNormal: smoothOutBack,
        ),
      );

      // Dedicated sharp-normal Carmine Red / Indigo 3D Beveled Edge Wall!
      edgeFront.add(
        _addV(
          bone,
          pf + out * 0.004,
          out,
          edgeMat,
          outlineNormal: smoothOut,
        ),
      );
      edgeBack.add(
        _addV(
          bone,
          pb + out * 0.004,
          out,
          edgeMat,
          outlineNormal: smoothOutBack,
        ),
      );
    }

    for (int i = 0; i < segs; i++) {
      final int ni = (i + 1) % segs;
      _addTri(frontCenter, frontMidRing[i], frontMidRing[ni]);
      _addQuad(frontMidRing[i], frontMidRing[ni], frontRim[ni], frontRim[i]);

      _addTri(backCenter, backMidRing[ni], backMidRing[i]);
      _addQuad(backMidRing[ni], backMidRing[i], backRim[i], backRim[ni]);

      // Thick 3D Carmine Red / Indigo lateral edge band!
      _addQuad(edgeFront[i], edgeFront[ni], edgeBack[ni], edgeBack[i]);
    }

    // 3D Saddle-Stitch Perimeter Dashes on Front & Back
    for (int i = 1; i < segs - 1; i += 2) {
      final int ni = (i + 1) % segs;
      final Vec3 s0 = Vec3.lerp(centerMid, perimMid[i], 0.84);
      final Vec3 s1 = Vec3.lerp(centerMid, perimMid[ni], 0.84);
      final Vec3 tang = (s1 - s0).normalized;
      final Vec3 perp = tang.cross(frontN).normalized * 0.011;
      for (final double sign in const <double>[1.0, -1.0]) {
        final Vec3 n = frontN * sign;
        final Vec3 lift = n * (halfT + 0.012);
        final int a = _addV(bone, s0 - perp + lift, n, stitchMat);
        final int b = _addV(bone, s0 + perp + lift, n, stitchMat);
        final int c = _addV(bone, s1 + perp + lift, n, stitchMat);
        final int d = _addV(bone, s1 - perp + lift, n, stitchMat);
        _addQuad(a, b, c, d, castOutline: false);
      }
    }

    // 3D LV Monogram Star/Flower Emblems on Front & Back of Petals
    final double starR = showLargeMonogram ? 0.125 : 0.072;
    for (final double sign in const <double>[1.0, -1.0]) {
      final Vec3 n = frontN * sign;
      addStarFlowerRelief3D(
        bone: bone,
        center: centerMid + n * (halfT + 0.020),
        uAxis: widthAxis,
        vAxis: dirAxis,
        normal: n,
        outerRadius: starR,
        innerRadius: starR * 0.34,
        reliefDepth: 0.018,
        mat: motifMat,
      );
    }
  }

  /// Builds a full 3D Parabolic Ski + 24K Gold Bindings attached to `skiBone` (`Ski_L` or `Ski_R`).
  void addParabolicSki3D({
    required VivienneBoneId skiBone,
    required double centerX,
    required VivienneSkiEdition edition,
  }) {
    final _MatSpec3D deckMat = _MatSpec3D(
      edition.skiDeckColor,
      specStrength: 0.42,
      shininess: 18.0,
    );
    final _MatSpec3D accentMat = _MatSpec3D(
      edition.skiAccentColor,
      specStrength: 0.65,
      shininess: 24.0,
    );
    final _MatSpec3D baseMat = const _MatSpec3D(
      Color(0xFF1A222C),
      specStrength: 0.50,
      shininess: 20.0,
    );
    final _MatSpec3D goldMat = const _MatSpec3D(
      Color(0xFFFFD700),
      specStrength: 0.88,
      shininess: 30.0,
    );

    // Ski stations from Tail (+Y = +0.66) to Upturned Shovel Tip (-Y = -0.84)
    const List<(double, double, double)> stations = <(double, double, double)>[
      (0.66, 0.072, 0.024), // Rounded tail lift
      (0.56, 0.078, 0.010),
      (0.20, 0.068, 0.010), // Parabolic waist
      (-0.22, 0.068, 0.010),
      (-0.56, 0.084, 0.014), // Wide shovel
      (-0.74, 0.074, 0.072), // Curved 3D upturned tip
      (-0.85, 0.032, 0.155), // Pointed 3D tip apex
    ];
    const double thick = 0.028;

    final List<int> topL = <int>[];
    final List<int> topR = <int>[];
    final List<int> botL = <int>[];
    final List<int> botR = <int>[];
    final List<int> sideTL = <int>[];
    final List<int> sideBL = <int>[];
    final List<int> sideTR = <int>[];
    final List<int> sideBR = <int>[];

    for (int i = 0; i < stations.length; i++) {
      final (double y, double hw, double zTop) = stations[i];
      final double zBot = zTop - thick;
      final Vec3 upN = i >= 5
          ? const Vec3(0.0, 0.45, 0.89)
          : Vec3.unitZ;
      topL.add(
        _addV(
          skiBone,
          Vec3(centerX + hw, y, zTop),
          upN,
          deckMat,
          outlineNormal: const Vec3(0.55, 0.0, 0.83),
          isSkiGear: true,
        ),
      );
      topR.add(
        _addV(
          skiBone,
          Vec3(centerX - hw, y, zTop),
          upN,
          deckMat,
          outlineNormal: const Vec3(-0.55, 0.0, 0.83),
          isSkiGear: true,
        ),
      );
      botL.add(
        _addV(
          skiBone,
          Vec3(centerX + hw, y, zBot),
          -upN,
          baseMat,
          outlineNormal: const Vec3(0.55, 0.0, -0.83),
          isSkiGear: true,
        ),
      );
      botR.add(
        _addV(
          skiBone,
          Vec3(centerX - hw, y, zBot),
          -upN,
          baseMat,
          outlineNormal: const Vec3(-0.55, 0.0, -0.83),
          isSkiGear: true,
        ),
      );

      sideTL.add(
        _addV(
          skiBone,
          Vec3(centerX + hw, y, zTop),
          Vec3.unitX,
          accentMat,
          outlineNormal: Vec3.unitX,
          isSkiGear: true,
        ),
      );
      sideBL.add(
        _addV(
          skiBone,
          Vec3(centerX + hw, y, zBot),
          Vec3.unitX,
          accentMat,
          outlineNormal: Vec3.unitX,
          isSkiGear: true,
        ),
      );
      sideTR.add(
        _addV(
          skiBone,
          Vec3(centerX - hw, y, zTop),
          -Vec3.unitX,
          accentMat,
          outlineNormal: -Vec3.unitX,
          isSkiGear: true,
        ),
      );
      sideBR.add(
        _addV(
          skiBone,
          Vec3(centerX - hw, y, zBot),
          -Vec3.unitX,
          accentMat,
          outlineNormal: -Vec3.unitX,
          isSkiGear: true,
        ),
      );
    }

    for (int i = 0; i < stations.length - 1; i++) {
      _addQuad(topR[i], topL[i], topL[i + 1], topR[i + 1], isSkiGear: true);
      _addQuad(botL[i], botR[i], botR[i + 1], botL[i + 1], isSkiGear: true);
      _addQuad(sideTL[i], sideBL[i], sideBL[i + 1], sideTL[i + 1], isSkiGear: true);
      _addQuad(sideBR[i], sideTR[i], sideTR[i + 1], sideBR[i + 1], isSkiGear: true);
    }
    // Tail & Tip end caps
    _addQuad(sideTR.first, sideTL.first, sideBL.first, sideBR.first, isSkiGear: true);
    _addQuad(
      sideTL.last,
      sideTR.last,
      sideBR.last,
      sideBL.last,
      isSkiGear: true,
    );

    // 24K Gold Toe & Heel 3D Bindings
    addBeveledBox3D(
      bone: skiBone,
      center: Vec3(centerX, -0.16, 0.036),
      halfExtents: const Vec3(0.062, 0.045, 0.024),
      faceMat: goldMat,
      isSkiGear: true,
    );
    addBeveledBox3D(
      bone: skiBone,
      center: Vec3(centerX, 0.15, 0.042),
      halfExtents: const Vec3(0.058, 0.048, 0.028),
      faceMat: goldMat,
      isSkiGear: true,
    );
  }
}

_EditionVolumetricMesh _buildEditionMesh(VivienneSkiEdition edition) {
  final _RigMeshBuilder b = _RigMeshBuilder();

  // Shared luxury material palette faithful to BLENDER_LAB Python generators
  final Color woodBase = switch (edition) {
    VivienneSkiEdition.speedyV03 => const Color(0xFFD5B08E),
    VivienneSkiEdition.wonderland => const Color(0xFFCCA077),
    VivienneSkiEdition.giantDenim => const Color(0xFFDFB98B),
  };
  final _MatSpec3D woodMat = _MatSpec3D(
    woodBase,
    specStrength: 0.30,
    shininess: 15.0,
  );
  final _MatSpec3D vachettaMat = const _MatSpec3D(
    Color(0xFFE3A17B),
    specStrength: 0.24,
    shininess: 12.0,
  );
  final _MatSpec3D carmineEdgeMat = const _MatSpec3D(
    Color(0xFF8B1E24),
    specStrength: 0.58,
    shininess: 22.0,
  );
  final _MatSpec3D denimEdgeMat = const _MatSpec3D(
    Color(0xFF1D3557),
    specStrength: 0.45,
    shininess: 18.0,
  );
  final _MatSpec3D gold24kMat = const _MatSpec3D(
    Color(0xFFFFD700),
    specStrength: 0.90,
    shininess: 30.0,
  );
  final _MatSpec3D darkEngraveMat = const _MatSpec3D(
    Color(0xFF2B1D14),
    specStrength: 0.35,
    shininess: 16.0,
  );

  final _MatSpec3D petalFaceMat = _MatSpec3D(
    edition.petalColor,
    specStrength: edition == VivienneSkiEdition.wonderland ? 0.34 : 0.24,
    shininess: 14.0,
  );
  final _MatSpec3D petalEdgeMat = edition == VivienneSkiEdition.giantDenim
      ? denimEdgeMat
      : carmineEdgeMat;
  final _MatSpec3D stitchMat = _MatSpec3D(
    edition.stitchGoldColor,
    specStrength: 0.50,
    shininess: 18.0,
  );
  final _MatSpec3D motifMat = _MatSpec3D(
    edition == VivienneSkiEdition.speedyV03
        ? const Color(0xFFC58B59)
        : edition.motifColor,
    specStrength: 0.48,
    shininess: 18.0,
  );
  final _MatSpec3D eyeFlowerMat = _MatSpec3D(
    edition.eyeFlowerColor,
    specStrength: 0.65,
    shininess: 24.0,
  );

  // ===========================================================================
  // 1. TÊTE 3D (`Vivienne_Head` — rx=0.45, ry=0.28, rz=0.45, Z=1.35 => 0.56m Y-depth!)
  // ===========================================================================
  b.addEllipsoid(
    bone: VivienneBoneId.head,
    center: const Vec3(0.0, -0.02, 1.35),
    radii: const Vec3(0.45, 0.28, 1.0 * 0.45),
    mat: woodMat,
    rings: 12,
    segs: 20,
    woodGrain: true,
  );

  // Right Eye (`X < 0`, `-Y` front face): 3D Domed 4-Petal Monogram Flower + Gold Stud
  b.addStarFlowerRelief3D(
    bone: VivienneBoneId.head,
    center: const Vec3(-0.195, -0.282, 1.375),
    uAxis: Vec3.unitX,
    vAxis: Vec3.unitZ,
    normal: const Vec3(-0.28, -0.95, 0.08).normalized,
    outerRadius: 0.175,
    innerRadius: 0.056,
    reliefDepth: 0.042,
    mat: eyeFlowerMat,
    castOutline: true,
  );
  b.addEllipsoid(
    bone: VivienneBoneId.head,
    center: const Vec3(-0.198, -0.318, 1.378),
    radii: const Vec3(0.036, 0.026, 0.036),
    mat: gold24kMat,
    rings: 6,
    segs: 10,
    castOutline: false,
  );

  // Left Eye (`X > 0`, `-Y` front face): 3D Beveled Gold Cylinder Stud + Dark Ring
  b.addCappedLimb(
    bone: VivienneBoneId.head,
    p0: const Vec3(0.195, -0.268, 1.355),
    p1: const Vec3(0.206, -0.318, 1.355),
    rx0: 0.052,
    ry0: 0.052,
    rx1: 0.046,
    ry1: 0.046,
    mat: darkEngraveMat,
    segs: 10,
    stacks: 1,
    castOutline: true,
  );
  b.addCappedLimb(
    bone: VivienneBoneId.head,
    p0: const Vec3(0.200, -0.285, 1.355),
    p1: const Vec3(0.212, -0.330, 1.355),
    rx0: 0.038,
    ry0: 0.038,
    rx1: 0.034,
    ry1: 0.034,
    mat: gold24kMat,
    segs: 10,
    stacks: 1,
    castOutline: false,
  );

  // Side Vachetta Leather Ears (`Vivienne_Ear_Left` & `Vivienne_Ear_Right`) with Red Edge
  for (final double sx in const <double>[-1.0, 1.0]) {
    b.addBeveledBox3D(
      bone: VivienneBoneId.head,
      center: Vec3(sx * 0.435, -0.09, 1.35),
      halfExtents: const Vec3(0.048, 0.022, 0.085),
      faceMat: vachettaMat,
      sideEdgeMat: carmineEdgeMat,
      topBottomMat: carmineEdgeMat,
    );
  }

  // ===========================================================================
  // 2. COROLLE À 4 PÉTALES 3D VOLUMÉTRIQUES (`thickness = 0.072`, tranches #8B1E24)
  // ===========================================================================
  final bool bigMonogram = edition != VivienneSkiEdition.speedyV03;
  // Top Petal (+Z)
  b.addVolumetricPetal3D(
    bone: VivienneBoneId.petalTop,
    basePivot: const Vec3(0.0, -0.09, 1.69),
    dirAxis: Vec3.unitZ,
    widthAxis: Vec3.unitX,
    length: 0.58,
    maxWidth: 0.47,
    thickness: 0.072,
    forwardCup: 0.055,
    faceMat: petalFaceMat,
    edgeMat: petalEdgeMat,
    stitchMat: stitchMat,
    motifMat: motifMat,
    showLargeMonogram: bigMonogram,
  );
  // Bottom Petal (-Z, drapes forward -Y over chest like a bib!)
  b.addVolumetricPetal3D(
    bone: VivienneBoneId.petalBottom,
    basePivot: const Vec3(0.0, -0.15, 1.02),
    dirAxis: const Vec3(0.0, -0.22, -0.975).normalized,
    widthAxis: Vec3.unitX,
    length: 0.54,
    maxWidth: 0.45,
    thickness: 0.072,
    forwardCup: 0.065,
    faceMat: petalFaceMat,
    edgeMat: petalEdgeMat,
    stitchMat: stitchMat,
    motifMat: motifMat,
    showLargeMonogram: bigMonogram,
  );
  // Left Petal in Viewer Front (-X)
  b.addVolumetricPetal3D(
    bone: VivienneBoneId.petalLeft,
    basePivot: const Vec3(-0.39, -0.09, 1.35),
    dirAxis: -Vec3.unitX,
    widthAxis: Vec3.unitZ,
    length: 0.56,
    maxWidth: 0.46,
    thickness: 0.072,
    forwardCup: 0.055,
    faceMat: petalFaceMat,
    edgeMat: petalEdgeMat,
    stitchMat: stitchMat,
    motifMat: motifMat,
    showLargeMonogram: bigMonogram,
  );
  // Right Petal in Viewer Front (+X)
  b.addVolumetricPetal3D(
    bone: VivienneBoneId.petalRight,
    basePivot: const Vec3(0.39, -0.09, 1.35),
    dirAxis: Vec3.unitX,
    widthAxis: Vec3.unitZ,
    length: 0.56,
    maxWidth: 0.46,
    thickness: 0.072,
    forwardCup: 0.055,
    faceMat: petalFaceMat,
    edgeMat: petalEdgeMat,
    stitchMat: stitchMat,
    motifMat: motifMat,
    showLargeMonogram: bigMonogram,
  );

  // ===========================================================================
  // 3. TORSE & BASSIN 3D (`Vivienne_Torso` — Pelvis & Spine, Z = 0.35..0.98)
  // ===========================================================================
  final _MatSpec3D torsoMat = edition == VivienneSkiEdition.wonderland
      ? const _MatSpec3D(Color(0xFF3A261B), specStrength: 0.30, shininess: 14.0)
      : woodMat;
  b.addEllipsoid(
    bone: VivienneBoneId.pelvis,
    center: const Vec3(0.0, 0.0, 0.44),
    radii: const Vec3(0.275, 0.215, 0.14),
    mat: torsoMat,
    rings: 6,
    segs: 14,
    woodGrain: true,
  );
  b.addCappedLimb(
    bone: VivienneBoneId.spine,
    p0: const Vec3(0.0, 0.0, 0.46),
    p1: const Vec3(0.0, 0.0, 0.99),
    rx0: 0.275,
    ry0: 0.215,
    rx1: 0.225,
    ry1: 0.185,
    mat: torsoMat,
    segs: 16,
    stacks: 3,
  );

  // 360° LV Monogram Star Reliefs around Torso (front, back, left, right!)
  if (edition != VivienneSkiEdition.giantDenim) {
    final _MatSpec3D torsoMotif = edition == VivienneSkiEdition.speedyV03
        ? const _MatSpec3D(Color(0xFF4A2E1B), specStrength: 0.38, shininess: 16.0)
        : motifMat;
    for (int k = 0; k < 6; k++) {
      final double ang = (k / 6.0) * 2.0 * math.pi;
      final double ca = math.cos(ang);
      final double sa = math.sin(ang);
      final Vec3 n = Vec3(ca, sa, 0.0);
      final Vec3 tang = Vec3(-sa, ca, 0.0);
      b.addStarFlowerRelief3D(
        bone: VivienneBoneId.spine,
        center: Vec3(ca * 0.258, sa * 0.202, k.isEven ? 0.68 : 0.80),
        uAxis: tang,
        vAxis: Vec3.unitZ,
        normal: n,
        outerRadius: 0.068,
        innerRadius: 0.024,
        reliefDepth: 0.014,
        mat: torsoMotif,
      );
    }
  }

  // ===========================================================================
  // 4. JAMBES, GENOUX, PIEDS / SNEAKERS 3D & SKIS PARABOLIQUES 3D INDÉPENDANTS
  // ===========================================================================
  for (final (
        double xPos,
        VivienneBoneId legBone,
        VivienneBoneId shinBone,
        VivienneBoneId footBone,
        VivienneBoneId skiBone,
      ) in <(
        double,
        VivienneBoneId,
        VivienneBoneId,
        VivienneBoneId,
        VivienneBoneId,
      )>[
    (
      0.136,
      VivienneBoneId.legL,
      VivienneBoneId.shinL,
      VivienneBoneId.footL,
      VivienneBoneId.skiL,
    ),
    (
      -0.136,
      VivienneBoneId.legR,
      VivienneBoneId.shinR,
      VivienneBoneId.footR,
      VivienneBoneId.skiR,
    ),
  ]) {
    // Hip & Knee 3D joint spheres (watertight at extreme scissor/backflip angles!)
    b.addEllipsoid(
      bone: legBone,
      center: Vec3(xPos, 0.0, 0.38),
      radii: const Vec3(0.112, 0.116, 0.095),
      mat: torsoMat,
      rings: 6,
      segs: 10,
      castOutline: false,
    );
    // Thigh (`Leg_L` / `Leg_R`)
    b.addCappedLimb(
      bone: legBone,
      p0: Vec3(xPos, 0.0, 0.39),
      p1: Vec3(xPos, 0.0, 0.215),
      rx0: 0.118,
      ry0: 0.124,
      rx1: 0.104,
      ry1: 0.110,
      mat: torsoMat,
      segs: 12,
      stacks: 2,
    );
    // Knee Sphere + Shin (`Shin_L` / `Shin_R`)
    b.addEllipsoid(
      bone: shinBone,
      center: Vec3(xPos, 0.0, 0.22),
      radii: const Vec3(0.100, 0.105, 0.085),
      mat: torsoMat,
      rings: 5,
      segs: 10,
      castOutline: false,
    );
    b.addCappedLimb(
      bone: shinBone,
      p0: Vec3(xPos, 0.0, 0.22),
      p1: Vec3(xPos, 0.0, 0.085),
      rx0: 0.104,
      ry0: 0.108,
      rx1: 0.094,
      ry1: 0.098,
      mat: woodMat,
      segs: 12,
      stacks: 2,
    );

    if (edition == VivienneSkiEdition.giantDenim) {
      // FULL 3D VOLUMETRIC STREETWEAR SNEAKER (`Vivienne_Sneaker_L/R`)!
      const _MatSpec3D fuchsiaSole = _MatSpec3D(
        Color(0xFFC9184A),
        specStrength: 0.45,
        shininess: 18.0,
      );
      const _MatSpec3D whiteMidsole = _MatSpec3D(
        Color(0xFFF4F4F6),
        specStrength: 0.32,
        shininess: 14.0,
      );
      const _MatSpec3D silverPanel = _MatSpec3D(
        Color(0xFFCFD4DC),
        specStrength: 0.72,
        shininess: 24.0,
      );
      const _MatSpec3D carmineHeel = _MatSpec3D(
        Color(0xFF9E1B32),
        specStrength: 0.50,
        shininess: 20.0,
      );
      const _MatSpec3D raspberryStrap = _MatSpec3D(
        Color(0xFFC2185B),
        specStrength: 0.55,
        shininess: 20.0,
      );

      // 1. Chunky 3D Fuchsia Outsole
      b.addBeveledBox3D(
        bone: footBone,
        center: Vec3(xPos, -0.045, 0.020),
        halfExtents: const Vec3(0.104, 0.188, 0.020),
        faceMat: fuchsiaSole,
      );
      // 2. Crisp 3D White Midsole
      b.addBeveledBox3D(
        bone: footBone,
        center: Vec3(xPos, -0.042, 0.052),
        halfExtents: const Vec3(0.100, 0.180, 0.018),
        faceMat: whiteMidsole,
      );
      // 3. Sculpted 3D Upper + Rounded Toe Box + Silver Side Panels
      b.addEllipsoid(
        bone: footBone,
        center: Vec3(xPos, -0.048, 0.095),
        radii: const Vec3(0.096, 0.162, 0.052),
        mat: whiteMidsole,
        rings: 6,
        segs: 12,
      );
      b.addBeveledBox3D(
        bone: footBone,
        center: Vec3(xPos, -0.03, 0.092),
        halfExtents: const Vec3(0.099, 0.085, 0.026),
        faceMat: silverPanel,
        sideEdgeMat: silverPanel,
        castOutline: false,
      );
      // 4. Carmine Heel Counter (+Y)
      b.addBeveledBox3D(
        bone: footBone,
        center: Vec3(xPos, 0.095, 0.098),
        halfExtents: const Vec3(0.084, 0.042, 0.036),
        faceMat: carmineHeel,
        castOutline: false,
      );
      // 5. 3 Ribbed Raspberry Tongue Bands (-Y instep)
      for (int sIdx = 0; sIdx < 3; sIdx++) {
        b.addBeveledBox3D(
          bone: footBone,
          center: Vec3(xPos, -0.105 - sIdx * 0.034, 0.118 - sIdx * 0.010),
          halfExtents: const Vec3(0.068, 0.012, 0.016),
          faceMat: raspberryStrap,
          castOutline: false,
        );
      }
    } else {
      // Sculpted 3D Wooden Monogram Ski Boot / Foot + Gold/Carmine Sole Trim
      b.addEllipsoid(
        bone: footBone,
        center: Vec3(xPos, -0.035, 0.065),
        radii: const Vec3(0.096, 0.145, 0.052),
        mat: woodMat,
        rings: 6,
        segs: 12,
        woodGrain: true,
      );
      b.addBeveledBox3D(
        bone: footBone,
        center: Vec3(xPos, -0.035, 0.022),
        halfExtents: const Vec3(0.092, 0.140, 0.018),
        faceMat: carmineEdgeMat,
        topBottomMat: darkEngraveMat,
      );
    }

    // Independent 3D Parabolic Ski attached to Foot (`Ski_L`, `Ski_R`)
    b.addParabolicSki3D(
      skiBone: skiBone,
      centerX: xPos,
      edition: edition,
    );
  }

  // ===========================================================================
  // 5. BRAS, AVANT-BRAS, BOUCLES DE MAIN, MOUSQUETONS OR & BÂTONS DE SKI 3D
  // ===========================================================================
  final _MatSpec3D armStrapFaceMat = edition == VivienneSkiEdition.wonderland
      ? const _MatSpec3D(Color(0xFF3A261B), specStrength: 0.32, shininess: 14.0)
      : (edition == VivienneSkiEdition.giantDenim ? petalFaceMat : vachettaMat);

  for (final (
        double sx,
        VivienneBoneId upBone,
        VivienneBoneId loBone,
        VivienneBoneId handBone,
        VivienneBoneId poleBone,
      ) in <(
        double,
        VivienneBoneId,
        VivienneBoneId,
        VivienneBoneId,
        VivienneBoneId,
      )>[
    (
      1.0,
      VivienneBoneId.armUpperL,
      VivienneBoneId.armLowerL,
      VivienneBoneId.handClaspL,
      VivienneBoneId.skiPoleL,
    ),
    (
      -1.0,
      VivienneBoneId.armUpperR,
      VivienneBoneId.armLowerR,
      VivienneBoneId.handClaspR,
      VivienneBoneId.skiPoleR,
    ),
  ]) {
    // Shoulder cap
    b.addEllipsoid(
      bone: upBone,
      center: Vec3(sx * 0.328, -0.135, 0.975),
      radii: const Vec3(0.048, 0.038, 0.048),
      mat: armStrapFaceMat,
      rings: 5,
      segs: 8,
      castOutline: false,
    );
    // Upper Arm 3D Thick Leather Strap (with Carmine Red lateral edges!)
    final Mat4 upRot = Mat4.aroundPivot(
      pivot: Vec3(sx * 0.374, -0.148, 0.85),
      ry: -sx * 0.34,
    );
    b.addBeveledBox3D(
      bone: upBone,
      center: Vec3(sx * 0.374, -0.148, 0.85),
      halfExtents: const Vec3(0.040, 0.024, 0.145),
      faceMat: armStrapFaceMat,
      sideEdgeMat: carmineEdgeMat,
      topBottomMat: carmineEdgeMat,
      localTransform: upRot,
    );

    // Elbow joint + Forearm 3D Thick Leather Strap
    b.addEllipsoid(
      bone: loBone,
      center: Vec3(sx * 0.42, -0.16, 0.72),
      radii: const Vec3(0.044, 0.034, 0.044),
      mat: carmineEdgeMat,
      rings: 5,
      segs: 8,
      castOutline: false,
    );
    final Mat4 loRot = Mat4.aroundPivot(
      pivot: Vec3(sx * 0.45, -0.17, 0.60),
      ry: -sx * 0.24,
    );
    b.addBeveledBox3D(
      bone: loBone,
      center: Vec3(sx * 0.45, -0.17, 0.60),
      halfExtents: const Vec3(0.038, 0.022, 0.135),
      faceMat: armStrapFaceMat,
      sideEdgeMat: carmineEdgeMat,
      topBottomMat: carmineEdgeMat,
      localTransform: loRot,
    );

    // Hand Loop + 24K Gold Clasp (`Hand_Clasp_L/R`)
    b.addEllipsoid(
      bone: handBone,
      center: Vec3(sx * 0.485, -0.18, 0.475),
      radii: const Vec3(0.048, 0.036, 0.048),
      mat: armStrapFaceMat,
      rings: 5,
      segs: 10,
    );
    b.addBeveledBox3D(
      bone: handBone,
      center: Vec3(sx * 0.495, -0.18, 0.425),
      halfExtents: const Vec3(0.024, 0.020, 0.032),
      faceMat: gold24kMat,
    );

    // 3D Ski Pole (`Ski_Pole_L/R`) with Grip, Gold/Carbon Shaft & Star Blossom Basket!
    b.addCappedLimb(
      bone: poleBone,
      p0: Vec3(sx * 0.50, -0.23, 0.52),
      p1: Vec3(sx * 0.50, -0.15, 0.39),
      rx0: 0.026,
      ry0: 0.026,
      rx1: 0.022,
      ry1: 0.022,
      mat: carmineEdgeMat,
      segs: 8,
      stacks: 1,
      isSkiGear: true,
    );
    b.addCappedLimb(
      bone: poleBone,
      p0: Vec3(sx * 0.50, -0.16, 0.41),
      p1: Vec3(sx * 0.54, 0.58, 0.03),
      rx0: 0.016,
      ry0: 0.016,
      rx1: 0.012,
      ry1: 0.012,
      mat: gold24kMat,
      segs: 8,
      stacks: 1,
      isSkiGear: true,
    );
    // Star Blossom 3D Snow Basket near pole tip
    b.addStarFlowerRelief3D(
      bone: poleBone,
      center: Vec3(sx * 0.535, 0.49, 0.08),
      uAxis: Vec3.unitX,
      vAxis: const Vec3(0.0, 0.48, 0.88).normalized,
      normal: const Vec3(0.0, -0.88, 0.48).normalized,
      outerRadius: 0.068,
      innerRadius: 0.028,
      reliefDepth: 0.020,
      mat: _MatSpec3D(edition.skiAccentColor, specStrength: 0.65, shininess: 22.0),
      isSkiGear: true,
      castOutline: true,
    );
  }

  // ===========================================================================
  // 6. ACCESSOIRES 3D VOLUMÉTRIQUES SPÉCIFIQUES AUX 3 ÉDITIONS BLENDER_LAB
  // ===========================================================================
  if (edition == VivienneSkiEdition.speedyV03) {
    // MINI SAC SPEEDY LV 3D (`Speedy_Bag_Bone` sur `Hand_Clasp_L`)
    const _MatSpec3D speedyCanvas = _MatSpec3D(
      Color(0xFF2B1D14),
      specStrength: 0.36,
      shininess: 16.0,
    );
    const Vec3 bagCenter = Vec3(0.56, -0.18, 0.24);
    // Horizontal 3D Barrel Body (0.34 x 0.22 x 0.24)
    b.addCappedLimb(
      bone: VivienneBoneId.speedyBagBone,
      p0: Vec3(bagCenter.x - 0.165, bagCenter.y, bagCenter.z),
      p1: Vec3(bagCenter.x + 0.165, bagCenter.y, bagCenter.z),
      rx0: 0.105,
      ry0: 0.115,
      rx1: 0.105,
      ry1: 0.115,
      mat: speedyCanvas,
      segs: 14,
      stacks: 2,
    );
    // Vachetta Side Piping Rings + Chapes
    for (final double dx in const <double>[-0.158, 0.158]) {
      b.addCappedLimb(
        bone: VivienneBoneId.speedyBagBone,
        p0: Vec3(bagCenter.x + dx - 0.012, bagCenter.y, bagCenter.z),
        p1: Vec3(bagCenter.x + dx + 0.012, bagCenter.y, bagCenter.z),
        rx0: 0.112,
        ry0: 0.122,
        rx1: 0.112,
        ry1: 0.122,
        mat: vachettaMat,
        segs: 12,
        stacks: 1,
        castOutline: false,
      );
    }
    // 2 Arched 3D Vachetta Top Handles (`-Y` front & `+Y` back) connecting to Hand_Clasp_L
    for (final double dy in const <double>[-0.065, 0.065]) {
      final Vec3 hLeft = Vec3(bagCenter.x - 0.085, bagCenter.y + dy, bagCenter.z + 0.10);
      final Vec3 hApex = Vec3(bagCenter.x - 0.02, bagCenter.y + dy * 0.55, bagCenter.z + 0.22);
      final Vec3 hRight = Vec3(bagCenter.x + 0.085, bagCenter.y + dy, bagCenter.z + 0.10);
      b.addCappedLimb(
        bone: VivienneBoneId.speedyBagBone,
        p0: hLeft,
        p1: hApex,
        rx0: 0.016,
        ry0: 0.016,
        rx1: 0.016,
        ry1: 0.016,
        mat: vachettaMat,
        segs: 8,
        stacks: 1,
      );
      b.addCappedLimb(
        bone: VivienneBoneId.speedyBagBone,
        p0: hApex,
        p1: hRight,
        rx0: 0.016,
        ry0: 0.016,
        rx1: 0.016,
        ry1: 0.016,
        mat: vachettaMat,
        segs: 8,
        stacks: 1,
      );
    }
    // Gold Zipper Ridge & 3D Monogram Stars on Front & Back of Speedy
    b.addBeveledBox3D(
      bone: VivienneBoneId.speedyBagBone,
      center: Vec3(bagCenter.x, bagCenter.y, bagCenter.z + 0.118),
      halfExtents: const Vec3(0.145, 0.014, 0.010),
      faceMat: gold24kMat,
      castOutline: false,
    );
    for (final double sy in const <double>[-1.0, 1.0]) {
      b.addStarFlowerRelief3D(
        bone: VivienneBoneId.speedyBagBone,
        center: Vec3(bagCenter.x, bagCenter.y + sy * 0.112, bagCenter.z),
        uAxis: Vec3.unitX,
        vAxis: Vec3.unitZ,
        normal: Vec3(0.0, sy, 0.0),
        outerRadius: 0.058,
        innerRadius: 0.022,
        reliefDepth: 0.014,
        mat: gold24kMat,
      );
    }
  } else if (edition == VivienneSkiEdition.wonderland) {
    // 6A. PETIT LAPIN BLANC 3D (`Bunny_Body_Bone` & `Bunny_Ears_Bone` sur `Petal_Top`)
    const _MatSpec3D pearlBunnyMat = _MatSpec3D(
      Color(0xFFF7F5F0),
      specStrength: 0.34,
      shininess: 16.0,
    );
    const _MatSpec3D pinkEarMat = _MatSpec3D(
      Color(0xFFF2B5C4),
      specStrength: 0.28,
      shininess: 12.0,
    );

    // Plump 3D Bunny Body + Head + Paws + Fluffy Rear Pom-Pom Tail (+Y)
    b.addEllipsoid(
      bone: VivienneBoneId.bunnyBodyBone,
      center: const Vec3(0.0, -0.14, 2.31),
      radii: const Vec3(0.105, 0.095, 0.095),
      mat: pearlBunnyMat,
      rings: 8,
      segs: 14,
    );
    b.addEllipsoid(
      bone: VivienneBoneId.bunnyBodyBone,
      center: const Vec3(0.0, -0.155, 2.44),
      radii: const Vec3(0.092, 0.086, 0.082),
      mat: pearlBunnyMat,
      rings: 8,
      segs: 14,
    );
    // Fluffy Rear Tail Pom-Pom (+Y, clearly visible in 180° ski rear view!)
    b.addEllipsoid(
      bone: VivienneBoneId.bunnyBodyBone,
      center: const Vec3(0.0, -0.035, 2.29),
      radii: const Vec3(0.048, 0.048, 0.048),
      mat: pearlBunnyMat,
      rings: 6,
      segs: 10,
    );
    // Front Paws & Feet + Gold Eyes & Pink Nose (-Y)
    for (final double sx in const <double>[-1.0, 1.0]) {
      b.addEllipsoid(
        bone: VivienneBoneId.bunnyBodyBone,
        center: Vec3(sx * 0.068, -0.215, 2.255),
        radii: const Vec3(0.034, 0.042, 0.028),
        mat: pearlBunnyMat,
        rings: 5,
        segs: 8,
      );
      b.addEllipsoid(
        bone: VivienneBoneId.bunnyBodyBone,
        center: Vec3(sx * 0.038, -0.238, 2.452),
        radii: const Vec3(0.016, 0.014, 0.016),
        mat: gold24kMat,
        rings: 4,
        segs: 8,
        castOutline: false,
      );
    }
    b.addEllipsoid(
      bone: VivienneBoneId.bunnyBodyBone,
      center: const Vec3(0.0, -0.245, 2.428),
      radii: const Vec3(0.015, 0.014, 0.012),
      mat: pinkEarMat,
      rings: 4,
      segs: 8,
      castOutline: false,
    );

    // 2 Long Elastic 3D Bunny Ears (`Bunny_Ears_Bone`) with Pink Inner Channels
    for (final double sx in const <double>[-1.0, 1.0]) {
      b.addEllipsoid(
        bone: VivienneBoneId.bunnyEarsBone,
        center: Vec3(sx * 0.052, -0.155, 2.60),
        radii: const Vec3(0.036, 0.024, 0.125),
        mat: pearlBunnyMat,
        rings: 7,
        segs: 10,
      );
      b.addEllipsoid(
        bone: VivienneBoneId.bunnyEarsBone,
        center: Vec3(sx * 0.052, -0.174, 2.595),
        radii: const Vec3(0.020, 0.010, 0.088),
        mat: pinkEarMat,
        rings: 5,
        segs: 8,
        castOutline: false,
      );
    }

    // 6B. BALLON CŒUR LAQUÉ 3D + TIGE OR (`Speedy_Bag_Bone` sur `Hand_Clasp_L`)
    const _MatSpec3D heartLacquerMat = _MatSpec3D(
      Color(0xFFD91E48),
      specStrength: 0.78,
      shininess: 28.0,
    );
    // 3D Cylindrical Gold Stem rising above left hand
    b.addCappedLimb(
      bone: VivienneBoneId.speedyBagBone,
      p0: const Vec3(0.51, -0.18, 0.42),
      p1: const Vec3(0.68, -0.20, 1.12),
      rx0: 0.016,
      ry0: 0.016,
      rx1: 0.014,
      ry1: 0.014,
      mat: gold24kMat,
      segs: 8,
      stacks: 1,
    );
    // Plump Double-Lobe 3D Heart Balloon (`depth = 0.175m` in Y!)
    const Vec3 hCenter = Vec3(0.71, -0.20, 1.28);
    b.addEllipsoid(
      bone: VivienneBoneId.speedyBagBone,
      center: Vec3(hCenter.x - 0.082, hCenter.y, hCenter.z + 0.065),
      radii: const Vec3(0.115, 0.088, 0.112),
      mat: heartLacquerMat,
      rings: 8,
      segs: 12,
    );
    b.addEllipsoid(
      bone: VivienneBoneId.speedyBagBone,
      center: Vec3(hCenter.x + 0.082, hCenter.y, hCenter.z + 0.065),
      radii: const Vec3(0.115, 0.088, 0.112),
      mat: heartLacquerMat,
      rings: 8,
      segs: 12,
    );
    b.addCappedLimb(
      bone: VivienneBoneId.speedyBagBone,
      p0: Vec3(hCenter.x, hCenter.y, hCenter.z + 0.03),
      p1: Vec3(hCenter.x, hCenter.y, hCenter.z - 0.145),
      rx0: 0.155,
      ry0: 0.082,
      rx1: 0.022,
      ry1: 0.020,
      mat: heartLacquerMat,
      segs: 12,
      stacks: 2,
    );
    // Raised 3D Gold Star Flower on BOTH Front (-Y) and Back (+Y) of Heart Balloon!
    for (final double sy in const <double>[-1.0, 1.0]) {
      b.addStarFlowerRelief3D(
        bone: VivienneBoneId.speedyBagBone,
        center: Vec3(hCenter.x, hCenter.y + sy * 0.090, hCenter.z + 0.035),
        uAxis: Vec3.unitX,
        vAxis: Vec3.unitZ,
        normal: Vec3(0.0, sy, 0.0),
        outerRadius: 0.085,
        innerRadius: 0.030,
        reliefDepth: 0.020,
        mat: gold24kMat,
      );
    }
  } else if (edition == VivienneSkiEdition.giantDenim) {
    // 6A. MINI SKATEBOARD LV 3D À 4 ROUES CYLINDRIQUES (`Speedy_Bag_Bone` sur `Hand_Clasp_L`)
    const _MatSpec3D gripDeckMat = _MatSpec3D(
      Color(0xFF1D2A3A),
      specStrength: 0.25,
      shininess: 12.0,
    );
    const _MatSpec3D maplePlyMat = _MatSpec3D(
      Color(0xFFF4EFE6),
      specStrength: 0.30,
      shininess: 12.0,
    );
    const _MatSpec3D chromeTruckMat = _MatSpec3D(
      Color(0xFFD0D6DF),
      specStrength: 0.85,
      shininess: 28.0,
    );
    const _MatSpec3D creamWheelMat = _MatSpec3D(
      Color(0xFFF2EFE9),
      specStrength: 0.42,
      shininess: 16.0,
    );

    const Vec3 skCenter = Vec3(0.58, -0.16, 0.34);
    // Main 3D Deck + Double Kicktails
    b.addBeveledBox3D(
      bone: VivienneBoneId.speedyBagBone,
      center: skCenter,
      halfExtents: const Vec3(0.016, 0.098, 0.22),
      faceMat: maplePlyMat,
      sideEdgeMat: gripDeckMat,
      topBottomMat: maplePlyMat,
    );
    // Top & Bottom Angled Kicktails
    for (final double sz in const <double>[-1.0, 1.0]) {
      final Vec3 ktPos = Vec3(skCenter.x - 0.018, skCenter.y, skCenter.z + sz * 0.255);
      final Mat4 ktRot = Mat4.aroundPivot(
        pivot: ktPos,
        ry: sz * 0.32,
      );
      b.addBeveledBox3D(
        bone: VivienneBoneId.speedyBagBone,
        center: ktPos,
        halfExtents: const Vec3(0.015, 0.088, 0.058),
        faceMat: maplePlyMat,
        sideEdgeMat: petalFaceMat,
        localTransform: ktRot,
      );
    }
    // Denim Monogram Star on Skateboard Deck Underside (+X)
    b.addStarFlowerRelief3D(
      bone: VivienneBoneId.speedyBagBone,
      center: Vec3(skCenter.x + 0.020, skCenter.y, skCenter.z),
      uAxis: Vec3.unitY,
      vAxis: Vec3.unitZ,
      normal: Vec3.unitX,
      outerRadius: 0.072,
      innerRadius: 0.026,
      reliefDepth: 0.014,
      mat: motifMat,
    );
    // 2 Metallic Chrome 3D Trucks + 4 Cylindrical 3D Cream Wheels!
    for (final double tz in const <double>[-0.145, 0.145]) {
      final Vec3 truckPos = Vec3(skCenter.x + 0.036, skCenter.y, skCenter.z + tz);
      b.addBeveledBox3D(
        bone: VivienneBoneId.speedyBagBone,
        center: truckPos,
        halfExtents: const Vec3(0.020, 0.078, 0.020),
        faceMat: chromeTruckMat,
      );
      for (final double wy in const <double>[-0.088, 0.088]) {
        b.addCappedLimb(
          bone: VivienneBoneId.speedyBagBone,
          p0: Vec3(truckPos.x + 0.012, skCenter.y + wy - 0.018, truckPos.z),
          p1: Vec3(truckPos.x + 0.012, skCenter.y + wy + 0.018, truckPos.z),
          rx0: 0.036,
          ry0: 0.036,
          rx1: 0.036,
          ry1: 0.036,
          mat: creamWheelMat,
          segs: 10,
          stacks: 1,
        );
      }
    }

    // 6B. ÉTIQUETTE PORTE-ADRESSE LV 3D (`Swing_Tag_Bone` sur `Hand_Clasp_R`)
    const _MatSpec3D swingTagMat = _MatSpec3D(
      Color(0xFFDFC496),
      specStrength: 0.28,
      shininess: 14.0,
    );
    b.addCappedLimb(
      bone: VivienneBoneId.swingTagBone,
      p0: const Vec3(-0.50, -0.18, 0.43),
      p1: const Vec3(-0.54, -0.18, 0.34),
      rx0: 0.010,
      ry0: 0.010,
      rx1: 0.010,
      ry1: 0.010,
      mat: carmineEdgeMat,
      segs: 6,
      stacks: 1,
    );
    b.addBeveledBox3D(
      bone: VivienneBoneId.swingTagBone,
      center: const Vec3(-0.55, -0.18, 0.255),
      halfExtents: const Vec3(0.052, 0.016, 0.085),
      faceMat: swingTagMat,
      sideEdgeMat: carmineEdgeMat,
      topBottomMat: carmineEdgeMat,
    );
    b.addEllipsoid(
      bone: VivienneBoneId.swingTagBone,
      center: const Vec3(-0.55, -0.20, 0.29),
      radii: const Vec3(0.016, 0.010, 0.016),
      mat: gold24kMat,
      rings: 4,
      segs: 8,
      castOutline: false,
    );
  }

  return _EditionVolumetricMesh(vertices: b._verts, triangles: b._tris);
}

// =============================================================================
// 4. Real-Time 3D Volumetric Rasterizer, PBR Lighting & Projected Bounds
// =============================================================================

@immutable
class VivienneProjectedBounds {
  const VivienneProjectedBounds({
    required this.boundingBox,
    required this.worldMin,
    required this.worldMax,
    required this.renderedTriangleCount,
  });

  final Rect boundingBox;
  final Vec3 worldMin;
  final Vec3 worldMax;
  final int renderedTriangleCount;

  double get worldSpanX => worldMax.x - worldMin.x;
  double get worldSpanY => worldMax.y - worldMin.y;
  double get worldSpanZ => worldMax.z - worldMin.z;
}

class _SortableTri {
  const _SortableTri(this.depth, this.i0, this.i1, this.i2);

  final double depth;
  final int i0;
  final int i1;
  final int i2;
}

/// Real-time 3D Volumetric & 22-Bone Skeletal Renderer replacing all flat 2D sprites.
class Vivienne3DVolumetricRig {
  const Vivienne3DVolumetricRig._();

  static final Map<VivienneSkiEdition, _EditionVolumetricMesh> _meshCache =
      <VivienneSkiEdition, _EditionVolumetricMesh>{};

  static _EditionVolumetricMesh _meshFor(VivienneSkiEdition edition) {
    return _meshCache.putIfAbsent(edition, () => _buildEditionMesh(edition));
  }

  static final Paint _vertexPaint = Paint()..isAntiAlias = true;

  // 3-Point Studio Cycles PBR Lighting Vectors in Camera Space
  // Camera sits at (0, -camDist, camHeight) looking along +Y_cam (`viewDir = (0, -1, 0)`).
  static final Vec3 _keyLightDir = const Vec3(-0.46, -0.70, 0.54).normalized;
  static final Vec3 _fillLightDir = const Vec3(0.66, -0.44, 0.36).normalized;
  static final Vec3 _rimLightDir = const Vec3(0.12, 0.78, 0.61).normalized;
  static const Vec3 _viewDir = Vec3(0.0, -1.0, 0.0);
  static final Vec3 _halfKeyVec = (_keyLightDir + _viewDir).normalized;

  static int _shadeVertexPbr(Vec3 n, _MatSpec3D mat) {
    final double nDotKey = math.max(0.0, n.dot(_keyLightDir));
    final double nDotFill = math.max(0.0, n.dot(_fillLightDir));
    final double nDotRim = math.max(0.0, n.dot(_rimLightDir));

    // Hemisphere ambient (bright alpine sky + snow bounce from below)
    final double hemi = 0.42 + 0.08 * n.z;
    final double diffuse = hemi + nDotKey * 0.64 + nDotFill * 0.28 + nDotRim * 0.24;

    // Blinn-Phong studio specular highlight
    final double nDotH = math.max(0.0, n.dot(_halfKeyVec));
    final double spec = mat.specStrength *
        math.pow(nDotH, mat.shininess).toDouble();

    // Subtle crisp alpine rim highlight on grazing angles
    final double fresnel =
        math.pow((1.0 - math.max(0.0, n.dot(_viewDir))).clamp(0.0, 1.0), 3.0)
            .toDouble();
    final double specBoost = spec + fresnel * nDotRim * 0.22;

    final Color base = mat.color;
    final int r = ((base.r * 255.0) * diffuse + 255.0 * specBoost)
        .round()
        .clamp(0, 255);
    final int g = ((base.g * 255.0) * diffuse + 250.0 * specBoost)
        .round()
        .clamp(0, 255);
    final int bl = ((base.b * 255.0) * diffuse + 238.0 * specBoost)
        .round()
        .clamp(0, 255);
    return (0xFF << 24) | (r << 16) | (g << 8) | bl;
  }

  /// Computes exact projected 2D screen bounds and 3D world bounds for unit tests
  /// (verifying genuine 3D volumetric thickness at `yaw = 90°` and `yaw = 60°`!).
  static VivienneProjectedBounds computeProjectedBounds({
    required VivienneSkiEdition edition,
    required VivienneSkeletonPose3D pose,
    required Offset soleAnchorScreen,
    required double pixelsPerMeter,
    double cameraDistanceMeters = 6.2,
    double cameraElevationDegrees = 10.0,
    bool includeSkisAndPoles = true,
  }) {
    final _EditionVolumetricMesh mesh = _meshFor(edition);
    final double camPitch = cameraElevationDegrees * math.pi / 180.0;
    final Mat4 camRot = Mat4.aroundPivot(
      pivot: const Vec3(0.0, 0.0, 0.85),
      rx: camPitch,
    );

    double minScreenX = double.infinity;
    double maxScreenX = -double.infinity;
    double minScreenY = double.infinity;
    double maxScreenY = -double.infinity;

    double minWX = double.infinity, maxWX = -double.infinity;
    double minWY = double.infinity, maxWY = -double.infinity;
    double minWZ = double.infinity, maxWZ = -double.infinity;

    for (final _RigVertex3D v in mesh.vertices) {
      if (v.isSkiGear && !includeSkisAndPoles) continue;
      final Mat4 boneMat = pose[v.bone].worldMatrix;
      final Vec3 wp = boneMat.transformPoint(v.pos);
      if (wp.x < minWX) minWX = wp.x;
      if (wp.x > maxWX) maxWX = wp.x;
      if (wp.y < minWY) minWY = wp.y;
      if (wp.y > maxWY) maxWY = wp.y;
      if (wp.z < minWZ) minWZ = wp.z;
      if (wp.z > maxWZ) maxWZ = wp.z;

      final Vec3 cp = camRot.transformPoint(wp);
      final double depth = math.max(1.2, cameraDistanceMeters + cp.y);
      final double persp = cameraDistanceMeters / depth;
      final double sx = soleAnchorScreen.dx + cp.x * pixelsPerMeter * persp;
      final double sy = soleAnchorScreen.dy - cp.z * pixelsPerMeter * persp;
      if (sx < minScreenX) minScreenX = sx;
      if (sx > maxScreenX) maxScreenX = sx;
      if (sy < minScreenY) minScreenY = sy;
      if (sy > maxScreenY) maxScreenY = sy;
    }

    int frontTriCount = 0;
    for (final _RigTri3D tri in mesh.triangles) {
      if (tri.isSkiGear && !includeSkisAndPoles) continue;
      frontTriCount++;
    }

    return VivienneProjectedBounds(
      boundingBox: Rect.fromLTRB(minScreenX, minScreenY, maxScreenX, maxScreenY),
      worldMin: Vec3(minWX, minWY, minWZ),
      worldMax: Vec3(maxWX, maxWY, maxWZ),
      renderedTriangleCount: frontTriCount,
    );
  }

  static final Map<VivienneSkiEdition, _EditionScratchBuffers> _scratchByEdition =
      <VivienneSkiEdition, _EditionScratchBuffers>{};
  static final Map<int, VivienneSkeletonPose3D> _spectatorPoseCache =
      <int, VivienneSkeletonPose3D>{};
  static final Paint _studioShadowPaint =
      Paint()..color = const Color(0xFF14283C).withValues(alpha: 0.24);

  static _EditionScratchBuffers _scratchFor(
    VivienneSkiEdition edition,
    int vCount,
  ) {
    return _scratchByEdition.putIfAbsent(
      edition,
      () => _EditionScratchBuffers(vCount),
    );
  }

  /// Renders the full 3D volumetric & articulated Vivienne mesh onto `canvas`
  /// using `ui.Vertices.raw(ui.VertexMode.triangles, ...)` with Z-sorting,
  /// backface culling, 3D silhouette outlines, and 3-point Studio PBR lighting.
  static void paintCharacter({
    required Canvas canvas,
    required VivienneSkiEdition edition,
    required VivienneSkeletonPose3D pose,
    required Offset soleAnchorScreen,
    required double pixelsPerMeter,
    double cameraDistanceMeters = 6.2,
    double cameraElevationDegrees = 10.0,
    bool includeSkisAndPoles = true,
    bool drawStudioShadow = false,
    bool emitOutlineHull = true,
  }) {
    if (pixelsPerMeter <= 1.0) return;

    if (drawStudioShadow) {
      final Rect shadowRect = Rect.fromCenter(
        center: Offset(
          soleAnchorScreen.dx,
          soleAnchorScreen.dy + pixelsPerMeter * 0.04,
        ),
        width: pixelsPerMeter * 1.18,
        height: pixelsPerMeter * 0.30,
      );
      canvas.drawOval(shadowRect, _studioShadowPaint);
    }

    final _EditionVolumetricMesh mesh = _meshFor(edition);
    final int vCount = mesh.vertices.length;
    final _EditionScratchBuffers scratch = _scratchFor(edition, vCount);
    final Float32List xyPositions = scratch.xyPositions;
    final Int32List argbColors = scratch.argbColors;
    final Float64List camY = scratch.camY;
    final List<_SortableTri> drawList = scratch.drawList..clear();

    final double camPitch = cameraElevationDegrees * math.pi / 180.0;
    final Mat4 camRot = Mat4.aroundPivot(
      pivot: const Vec3(0.0, 0.0, 0.85),
      rx: camPitch,
    );

    // World-space outline extrusion radius calibrated so outlines stay razor-crisp at any zoom
    final double outlineWorldMeters =
        (2.15 / pixelsPerMeter).clamp(0.014, 0.032);
    const int outlineArgb = 0xFF2B1105;

    for (int i = 0; i < vCount; i++) {
      final _RigVertex3D rv = mesh.vertices[i];
      if (rv.isSkiGear && !includeSkisAndPoles) continue;

      final Mat4 boneMat = pose[rv.bone].worldMatrix;
      final Vec3 wp = boneMat.transformPoint(rv.pos);
      final Vec3 wn = boneMat.transformNormal(rv.normal);

      final Vec3 cp = camRot.transformPoint(wp);
      final Vec3 cn = camRot.transformNormal(wn);

      camY[i] = cp.y;

      final double depth = math.max(1.2, cameraDistanceMeters + cp.y);
      final double persp = cameraDistanceMeters / depth;
      final double sx = soleAnchorScreen.dx + cp.x * pixelsPerMeter * persp;
      final double sy = soleAnchorScreen.dy - cp.z * pixelsPerMeter * persp;

      xyPositions[i * 2] = sx;
      xyPositions[i * 2 + 1] = sy;
      argbColors[i] = _shadeVertexPbr(cn, rv.mat);

      if (emitOutlineHull) {
        final Vec3 wOutN = boneMat.transformNormal(rv.outlineNormal);
        final Vec3 cOutN = camRot.transformNormal(wOutN);
        final int oi = vCount + i;
        double ox = cOutN.x;
        double oz = cOutN.z;
        final double oLen = math.sqrt(ox * ox + oz * oz);
        if (oLen > 1e-5) {
          ox /= oLen;
          oz /= oLen;
        }
        final double ext = outlineWorldMeters * rv.mat.outlineScale;
        final double osx =
            soleAnchorScreen.dx + (cp.x + ox * ext) * pixelsPerMeter * persp;
        final double osy =
            soleAnchorScreen.dy - (cp.z + oz * ext) * pixelsPerMeter * persp;
        xyPositions[oi * 2] = osx;
        xyPositions[oi * 2 + 1] = osy;
        argbColors[oi] = outlineArgb;
      }
    }

    for (int t = 0; t < mesh.triangles.length; t++) {
      final _RigTri3D tri = mesh.triangles[t];
      if (tri.isSkiGear && !includeSkisAndPoles) continue;

      final int a = tri.i0;
      final int b = tri.i1;
      final int c = tri.i2;

      final double ax = xyPositions[a * 2];
      final double ay = xyPositions[a * 2 + 1];
      final double bx = xyPositions[b * 2];
      final double by = xyPositions[b * 2 + 1];
      final double cx = xyPositions[c * 2];
      final double cy = xyPositions[c * 2 + 1];

      // 2D screen-space signed area (on screen +X is right, +Y is DOWN, while +Z_cam is UP):
      // Outward front-facing CCW triangle in (X_cam, Z_cam) has `cross2D < 0` in (X_screen, Y_screen)!
      final double cross2D = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax);
      final double avgCamY = (camY[a] + camY[b] + camY[c]) * (1.0 / 3.0);

      if (cross2D <= 0.15) {
        drawList.add(_SortableTri(avgCamY, a, b, c));
      } else if (emitOutlineHull && tri.castOutline) {
        drawList.add(
          _SortableTri(
            avgCamY + 0.075,
            vCount + a,
            vCount + c,
            vCount + b,
          ),
        );
      }
    }

    if (drawList.isEmpty) return;

    // Painter's Algorithm Z-sort: larger `depth` (`+Y_cam`, further away) draws first!
    drawList.sort((_SortableTri lhs, _SortableTri rhs) =>
        rhs.depth.compareTo(lhs.depth));

    final Uint16List sortedIndices = Uint16List(drawList.length * 3);
    for (int i = 0; i < drawList.length; i++) {
      final _SortableTri st = drawList[i];
      final int base = i * 3;
      sortedIndices[base] = st.i0;
      sortedIndices[base + 1] = st.i1;
      sortedIndices[base + 2] = st.i2;
    }

    final ui.Vertices vertices = ui.Vertices.raw(
      ui.VertexMode.triangles,
      xyPositions,
      colors: argbColors,
      indices: sortedIndices,
    );
    canvas.drawVertices(vertices, BlendMode.dst, _vertexPaint);
    vertices.dispose();
  }

  /// High-level entry point called directly by `Ski3DPainter` for the 3D downhill ski slope!
  static void paintSkierOnSlope({
    required Canvas canvas,
    required SkiGameEngine engine,
    required Offset soleAnchorScreen,
    required double unitScalePx,
  }) {
    final bool airborne = engine.isAirborne;
    final SkiAerialTrickKind trick =
        airborne ? engine.currentAerialTrick : SkiAerialTrickKind.none;

    // 180° = Rear downhill view; Saut 360° adds full 0..360° 3D spin!
    double yawDeg = 180.0;
    double pitchDeg = 0.0;
    if (trick == SkiAerialTrickKind.saut360) {
      yawDeg = 180.0 + (engine.trickSpinAngle * 180.0 / math.pi);
    } else if (trick == SkiAerialTrickKind.sautPerilleux) {
      pitchDeg = engine.trickFlipAngle * 180.0 / math.pi;
    }

    final VivienneSkeletonPose3D pose = VivienneSkeletonPose3D.evaluate(
      edition: engine.selectedEdition,
      timeSeconds: engine.ambientTime + engine.elapsedSeconds,
      mode: VivienneMotionMode.skiRun,
      animState: engine.animState,
      aerialTrick: trick,
      isAirborne: airborne,
      yawDegrees: yawDeg,
      pitchDegrees: pitchDeg,
      rollRadians: engine.playerRollRadians,
      carveTilt: (engine.playerRollRadians / 0.40).clamp(-1.0, 1.0),
      trickProgress: engine.trickProgress,
      bagPendulumRadians: engine.speedyBagSwingRadians,
      squashStretchZ: engine.currentAnimScaleY,
    );

    // Calibrated so Vivienne's 2.27m 3D body matches the 3D alpine track perspective (`~3.85 * s`)
    final double pixelsPerMeter = unitScalePx * 1.66;

    paintCharacter(
      canvas: canvas,
      edition: engine.selectedEdition,
      pose: pose,
      soleAnchorScreen: soleAnchorScreen,
      pixelsPerMeter: pixelsPerMeter,
      cameraDistanceMeters: 6.0,
      cameraElevationDegrees: 14.0,
      includeSkisAndPoles: true,
    );
  }

  /// High-level 3D Spectator renderer along piste borders (`v1.4.0`):
  /// Uses all 3 `BLENDER_LAB` Vivienne models (`speedyV03`, `wonderland`, `giantDenim`)
  /// oriented 3/4-front toward the piste (`yaw ~ 45°` on left border, `~ 315°` on right border)
  /// with `VivienneMotionMode.spectatorCheer` (ZERO walk cycle!) and distance LOD for 60–120 FPS.
  static void paintSpectatorOnSlope({
    required Canvas canvas,
    required VivienneSkiEdition edition,
    required VivienneSpectatorCheerStyle cheerStyle,
    required Offset soleAnchorScreen,
    required double unitScalePx,
    required double timeSeconds,
    required bool isLeftOfTrack,
    double scaleMultiplier = 1.0,
    int yawVariant = 0,
  }) {
    final double pixelsPerMeter = unitScalePx * 1.48 * scaleMultiplier;
    if (pixelsPerMeter <= 4.2) return;

    // 3/4-front orientation turned toward the ski slope so her 3D wooden face,
    // 4 leather petals, Monogram eye, waving V-arms & two-footed jumps are clearly visible!
    final int clampedYawVar = yawVariant % 3;
    final double yawOffset = (clampedYawVar - 1) * 9.0;
    final double yawDegrees =
        (isLeftOfTrack ? 44.0 : 316.0) + yawOffset;

    // 72 quantized phase buckets per ~1.31s cheer cycle -> butter-smooth 60 FPS animation
    // while caching FK matrices across crowd members & frames!
    const double cyclePeriod = (2.0 * math.pi) / 4.8;
    final double wrappedTime =
        ((timeSeconds % (cyclePeriod * 2.0)) + cyclePeriod * 2.0) %
            (cyclePeriod * 2.0);
    final int phaseBucket =
        ((wrappedTime / (cyclePeriod * 2.0)) * 72.0).floor().clamp(0, 71);
    final int cacheKey = edition.index |
        (cheerStyle.index << 3) |
        ((isLeftOfTrack ? 1 : 0) << 6) |
        (clampedYawVar << 7) |
        (phaseBucket << 9);

    if (_spectatorPoseCache.length > 1200) {
      _spectatorPoseCache.clear();
    }
    final VivienneSkeletonPose3D pose = _spectatorPoseCache.putIfAbsent(
      cacheKey,
      () => VivienneSkeletonPose3D.evaluate(
        edition: edition,
        timeSeconds: (phaseBucket / 72.0) * (cyclePeriod * 2.0),
        mode: VivienneMotionMode.spectatorCheer,
        cheerStyle: cheerStyle,
        yawDegrees: yawDegrees,
      ),
    );

    // Adaptive LOD: crisp 3D silhouette hull for near/mid spectators; single-pass PBR at far distance
    final bool emitOutline = pixelsPerMeter >= 18.5;

    paintCharacter(
      canvas: canvas,
      edition: edition,
      pose: pose,
      soleAnchorScreen: soleAnchorScreen,
      pixelsPerMeter: pixelsPerMeter,
      cameraDistanceMeters: 6.4,
      cameraElevationDegrees: 12.0,
      includeSkisAndPoles: false,
      drawStudioShadow: true,
      emitOutlineHull: emitOutline,
    );
  }
}

class _EditionScratchBuffers {
  _EditionScratchBuffers(int vCount)
      : xyPositions = Float32List(vCount * 4),
        argbColors = Int32List(vCount * 2),
        camY = Float64List(vCount),
        drawList = <_SortableTri>[];

  final Float32List xyPositions;
  final Int32List argbColors;
  final Float64List camY;
  final List<_SortableTri> drawList;
}

// =============================================================================
// 5. Reusable Real-Time 60 FPS `Vivienne3DViewport` Widget (Menu, Gallery, Pause, Podium)
// =============================================================================

class Vivienne3DViewport extends StatefulWidget {
  const Vivienne3DViewport({
    super.key,
    required this.edition,
    this.yawDegrees = 25.0,
    this.pitchDegrees = 0.0,
    this.mode = VivienneMotionMode.showcase360,
    this.externalTimeSeconds,
    this.animate = true,
    this.includeSkisAndPoles = false,
    this.drawStudioShadow = true,
    this.cameraElevationDegrees = 8.0,
    this.onHorizontalDragYawDelta,
  });

  final VivienneSkiEdition edition;
  final double yawDegrees;
  final double pitchDegrees;
  final VivienneMotionMode mode;
  final double? externalTimeSeconds;
  final bool animate;
  final bool includeSkisAndPoles;
  final bool drawStudioShadow;
  final double cameraElevationDegrees;
  final ValueChanged<double>? onHorizontalDragYawDelta;

  @override
  State<Vivienne3DViewport> createState() => _Vivienne3DViewportState();
}

class _Vivienne3DViewportState extends State<Vivienne3DViewport>
    with SingleTickerProviderStateMixin {
  Ticker? _internalTicker;
  double _localTime = 0.42;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant Vivienne3DViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate ||
        (oldWidget.externalTimeSeconds == null) !=
            (widget.externalTimeSeconds == null)) {
      _syncTicker();
    }
  }

  void _syncTicker() {
    final bool needsInternal =
        widget.animate && widget.externalTimeSeconds == null;
    if (needsInternal && _internalTicker == null) {
      _internalTicker = createTicker((Duration elapsed) {
        if (!mounted) return;
        setState(() {
          _localTime =
              0.42 + elapsed.inMicroseconds / Duration.microsecondsPerSecond;
        });
      })
        ..start();
    } else if (!needsInternal && _internalTicker != null) {
      _internalTicker!.dispose();
      _internalTicker = null;
    }
  }

  @override
  void dispose() {
    _internalTicker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double activeTime = widget.externalTimeSeconds ?? _localTime;
    final Widget paintBox = RepaintBoundary(
      child: CustomPaint(
        painter: _Vivienne3DViewportPainter(
          edition: widget.edition,
          yawDegrees: widget.yawDegrees,
          pitchDegrees: widget.pitchDegrees,
          mode: widget.mode,
          timeSeconds: activeTime,
          includeSkisAndPoles: widget.includeSkisAndPoles,
          drawStudioShadow: widget.drawStudioShadow,
          cameraElevationDegrees: widget.cameraElevationDegrees,
        ),
        size: Size.infinite,
      ),
    );

    if (widget.onHorizontalDragYawDelta != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (DragUpdateDetails d) {
          widget.onHorizontalDragYawDelta!(d.delta.dx * 1.25);
        },
        child: paintBox,
      );
    }
    return paintBox;
  }
}

class _Vivienne3DViewportPainter extends CustomPainter {
  const _Vivienne3DViewportPainter({
    required this.edition,
    required this.yawDegrees,
    required this.pitchDegrees,
    required this.mode,
    required this.timeSeconds,
    required this.includeSkisAndPoles,
    required this.drawStudioShadow,
    required this.cameraElevationDegrees,
  });

  final VivienneSkiEdition edition;
  final double yawDegrees;
  final double pitchDegrees;
  final VivienneMotionMode mode;
  final double timeSeconds;
  final bool includeSkisAndPoles;
  final bool drawStudioShadow;
  final double cameraElevationDegrees;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 2.0 || size.height <= 2.0) return;

    final VivienneSkeletonPose3D pose = VivienneSkeletonPose3D.evaluate(
      edition: edition,
      timeSeconds: timeSeconds,
      mode: mode,
      yawDegrees: yawDegrees,
      pitchDegrees: pitchDegrees,
    );

    final double topModelMeters =
        edition == VivienneSkiEdition.wonderland ? 2.98 : 2.46;
    final double fitHeight = size.height * 0.84;
    final double fitWidth = size.width * (includeSkisAndPoles ? 0.56 : 0.70);
    final double pixelsPerMeter = math.min(
      fitHeight / topModelMeters,
      fitWidth / 2.02,
    );

    final Offset soleAnchor = Offset(
      size.width * 0.5,
      size.height * 0.91,
    );

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    Vivienne3DVolumetricRig.paintCharacter(
      canvas: canvas,
      edition: edition,
      pose: pose,
      soleAnchorScreen: soleAnchor,
      pixelsPerMeter: pixelsPerMeter,
      cameraDistanceMeters: 6.4,
      cameraElevationDegrees: cameraElevationDegrees,
      includeSkisAndPoles: includeSkisAndPoles,
      drawStudioShadow: drawStudioShadow,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _Vivienne3DViewportPainter oldDelegate) {
    return oldDelegate.edition != edition ||
        oldDelegate.yawDegrees != yawDegrees ||
        oldDelegate.pitchDegrees != pitchDegrees ||
        oldDelegate.mode != mode ||
        oldDelegate.timeSeconds != timeSeconds ||
        oldDelegate.includeSkisAndPoles != includeSkisAndPoles ||
        oldDelegate.drawStudioShadow != drawStudioShadow ||
        oldDelegate.cameraElevationDegrees != cameraElevationDegrees;
  }
}
