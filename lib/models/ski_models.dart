import 'package:flutter/material.dart';

/// The 3 completely skiable 3D Alpine tracks in `VIVI AU SKI : Descente Royale 3D` (`v1.1.0`).
enum SkiTrackId {
  greenBlossomValley(
    id: 'piste_verte',
    selectKeyName: 'select_track_piste_verte',
    title: 'Vallée Blossom Ensoleillée',
    shortTitle: 'Piste Verte',
    difficultyLabel: 'PISTE VERTE • DÉBUTANT',
    summaryMetrics: '1 200 m • Dénivelé -535 m (24°) • 4 Tremplins',
    description:
        'Ciel azur alpin, soleil radieux, pente dynamique à 24° (-535 m), banderoles LV_NEO, télécabines et 4 tremplins panoramiques.',
    lengthMeters: 1200.0,
    verticalDropMeters: 535.0,
    slopeDegrees: 24.0,
    baseSpeedKmh: 62.0,
    maxSpeedKmh: 108.0,
    targetTimeSeconds: 52.0,
    trackHalfWidthMeters: 15.5,
    curveAmplitudeMeters: 9.5,
    pineTreeCount: 42,
    mogulCount: 8,
    jumpRampCount: 4,
    slalomGateCount: 10,
    blossomCount: 35,
    skyTopColor: Color(0xFF1E88E5),
    skyMidColor: Color(0xFF64B5F6),
    skyHorizonColor: Color(0xFFB3E5FC),
    sunOrMoonColor: Color(0xFFFFF59D),
    mountainFarColor: Color(0xFF5C8DB8),
    mountainNearColor: Color(0xFF81B1D9),
    snowBrightColor: Color(0xFFFFFFFF),
    snowMidColor: Color(0xFFF2F9FF),
    snowShadowColor: Color(0xFFB3E5FC),
    pineDarkColor: Color(0xFF1B5E20),
    pineLightColor: Color(0xFF2E7D32),
    pineSnowColor: Color(0xFFF7FCFF),
    badgeColor: Color(0xFF00E676),
    badgeLipColor: Color(0xFF008E46),
    hasAuroraBorealis: false,
  ),
  blueAsnieresForest(
    id: 'piste_bleue',
    selectKeyName: 'select_track_piste_bleue',
    title: 'Forêt des Sapins d\'Asnières',
    shortTitle: 'Piste Bleue',
    difficultyLabel: 'PISTE BLEUE • CARVING',
    summaryMetrics: '1 800 m • Dénivelé -980 m (34°) • 7 Tremplins',
    description:
        'Soleil couchant doré, fort dénivelé -980 m (34°), sapins enneigés, banderoles LV_NEO et 16 bosses rythmées.',
    lengthMeters: 1800.0,
    verticalDropMeters: 980.0,
    slopeDegrees: 34.0,
    baseSpeedKmh: 84.0,
    maxSpeedKmh: 142.0,
    targetTimeSeconds: 64.0,
    trackHalfWidthMeters: 14.0,
    curveAmplitudeMeters: 14.0,
    pineTreeCount: 70,
    mogulCount: 16,
    jumpRampCount: 7,
    slalomGateCount: 14,
    blossomCount: 50,
    skyTopColor: Color(0xFF283593),
    skyMidColor: Color(0xFFEC8F6A),
    skyHorizonColor: Color(0xFFFFE082),
    sunOrMoonColor: Color(0xFFFFD54F),
    mountainFarColor: Color(0xFF5D538A),
    mountainNearColor: Color(0xFF8D78A8),
    snowBrightColor: Color(0xFFFFFCF5),
    snowMidColor: Color(0xFFF6EFE6),
    snowShadowColor: Color(0xFFC5CAE9),
    pineDarkColor: Color(0xFF1A4731),
    pineLightColor: Color(0xFF2E6B47),
    pineSnowColor: Color(0xFFFFF8EB),
    badgeColor: Color(0xFF29B6F6),
    badgeLipColor: Color(0xFF0277BD),
    hasAuroraBorealis: false,
  ),
  blackVendomePeaks(
    id: 'piste_noire',
    selectKeyName: 'select_track_piste_noire',
    title: 'Cimes Étoilées Vendôme',
    shortTitle: 'Piste Noire Or',
    difficultyLabel: 'PISTE NOIRE OR • EXPERT',
    summaryMetrics: '2 500 m • Dénivelé -1 650 m (45°) • 10 Méga-Sauts',
    description:
        'Nuit alpine étoilée sous aurore boréale, mur vertigineux à 45° (-1 650 m), vitesse extrême et 10 méga-tremplins Big Air.',
    lengthMeters: 2500.0,
    verticalDropMeters: 1650.0,
    slopeDegrees: 45.0,
    baseSpeedKmh: 108.0,
    maxSpeedKmh: 185.0,
    targetTimeSeconds: 76.0,
    trackHalfWidthMeters: 12.8,
    curveAmplitudeMeters: 18.0,
    pineTreeCount: 98,
    mogulCount: 24,
    jumpRampCount: 10,
    slalomGateCount: 18,
    blossomCount: 70,
    skyTopColor: Color(0xFF0D1B2A),
    skyMidColor: Color(0xFF1B3A4B),
    skyHorizonColor: Color(0xFF64DFDF),
    sunOrMoonColor: Color(0xFFFFD700),
    mountainFarColor: Color(0xFF1B263B),
    mountainNearColor: Color(0xFF2C4969),
    snowBrightColor: Color(0xFFF0FCFF),
    snowMidColor: Color(0xFFDFF6FA),
    snowShadowColor: Color(0xFF80DEEA),
    pineDarkColor: Color(0xFF103742),
    pineLightColor: Color(0xFF1F5D6B),
    pineSnowColor: Color(0xFFE0F7FA),
    badgeColor: Color(0xFFFFD700),
    badgeLipColor: Color(0xFF9E6B00),
    hasAuroraBorealis: true,
  );

  const SkiTrackId({
    required this.id,
    required this.selectKeyName,
    required this.title,
    required this.shortTitle,
    required this.difficultyLabel,
    required this.summaryMetrics,
    required this.description,
    required this.lengthMeters,
    required this.verticalDropMeters,
    required this.slopeDegrees,
    required this.baseSpeedKmh,
    required this.maxSpeedKmh,
    required this.targetTimeSeconds,
    required this.trackHalfWidthMeters,
    required this.curveAmplitudeMeters,
    required this.pineTreeCount,
    required this.mogulCount,
    required this.jumpRampCount,
    required this.slalomGateCount,
    required this.blossomCount,
    required this.skyTopColor,
    required this.skyMidColor,
    required this.skyHorizonColor,
    required this.sunOrMoonColor,
    required this.mountainFarColor,
    required this.mountainNearColor,
    required this.snowBrightColor,
    required this.snowMidColor,
    required this.snowShadowColor,
    required this.pineDarkColor,
    required this.pineLightColor,
    required this.pineSnowColor,
    required this.badgeColor,
    required this.badgeLipColor,
    required this.hasAuroraBorealis,
  });

  final String id;
  final String selectKeyName;
  final String title;
  final String shortTitle;
  final String difficultyLabel;
  final String summaryMetrics;
  final String description;
  final double lengthMeters;
  final double verticalDropMeters;
  final double slopeDegrees;
  final double baseSpeedKmh;
  final double maxSpeedKmh;
  final double targetTimeSeconds;
  final double trackHalfWidthMeters;
  final double curveAmplitudeMeters;
  final int pineTreeCount;
  final int mogulCount;
  final int jumpRampCount;
  final int slalomGateCount;
  final int blossomCount;
  final Color skyTopColor;
  final Color skyMidColor;
  final Color skyHorizonColor;
  final Color sunOrMoonColor;
  final Color mountainFarColor;
  final Color mountainNearColor;
  final Color snowBrightColor;
  final Color snowMidColor;
  final Color snowShadowColor;
  final Color pineDarkColor;
  final Color pineLightColor;
  final Color pineSnowColor;
  final Color badgeColor;
  final Color badgeLipColor;
  final bool hasAuroraBorealis;

  SkiTrackId get nextTrack {
    final List<SkiTrackId> all = SkiTrackId.values;
    return all[(index + 1) % all.length];
  }
}

/// The 4 official playable 3D Vivienne models from `orbitalstorm/BLENDER_LAB`.
enum VivienneSkiEdition {
  speedyV03(
    id: 'speedy_v03',
    name: 'Vivienne Speedy v03',
    blendPath: 'models/vivienne_speedy_v03.blend',
    heroAssetPath: 'assets/sprites/vivienne_speedy_v03_hero.png',
    subtitle: 'Chêne Clair, Vachetta & Mini Speedy LV',
    perkLabel: 'Glisse équilibrée +5 % • Impulsion +4 %',
    petalColor: Color(0xFFE3A17B),
    trimEdgeColor: Color(0xFF8B1E24),
    stitchGoldColor: Color(0xFFE5B842),
    eyeFlowerColor: Color(0xFF3A2618),
    motifColor: Color(0xFF3A2618),
    skiDeckColor: Color(0xFF2B1D14),
    skiAccentColor: Color(0xFFFFD700),
    scarfColor: Color(0xFF8B1E24),
    glideBonusMultiplier: 1.05,
    carvingMultiplier: 1.04,
    jumpBoostMultiplier: 1.04,
    scoreMultiplier: 1.00,
    blossomMagnetMeters: 2.3,
  ),
  wonderland(
    id: 'wonderland',
    name: 'Vivienne Wonderland',
    blendPath: 'models/vivienne_wonderland.blend',
    heroAssetPath: 'assets/sprites/vivienne_wonderland_hero.png',
    subtitle: 'Monogram Ébène, Lapin Blanc & Ballon Cœur',
    perkLabel: 'Big Air Féerique +12 % • Score Prestige ×1.20',
    petalColor: Color(0xFF2B1D14),
    trimEdgeColor: Color(0xFF6D4C41),
    stitchGoldColor: Color(0xFFE5B842),
    eyeFlowerColor: Color(0xFF2B95EA),
    motifColor: Color(0xFFA6825B),
    skiDeckColor: Color(0xFF2B1D14),
    skiAccentColor: Color(0xFF2B95EA),
    scarfColor: Color(0xFFD91E48),
    glideBonusMultiplier: 1.07,
    carvingMultiplier: 1.08,
    jumpBoostMultiplier: 1.12,
    scoreMultiplier: 1.20,
    blossomMagnetMeters: 2.8,
  ),
  giantDenim(
    id: 'giant_denim',
    name: 'Vivienne Giant Denim',
    blendPath: 'models/vivienne_giant_denim.blend',
    heroAssetPath: 'assets/sprites/vivienne_giant_denim_hero.png',
    subtitle: 'Denim Jacquard, Sneakers & Skateboard LV',
    perkLabel: 'Carving Street +16 % • Vitesse de pointe +8 %',
    petalColor: Color(0xFF3B6291),
    trimEdgeColor: Color(0xFF1E3A5F),
    stitchGoldColor: Color(0xFFF4F8FC),
    eyeFlowerColor: Color(0xFFE31C58),
    motifColor: Color(0xFFD6E2F0),
    skiDeckColor: Color(0xFF1E3A5F),
    skiAccentColor: Color(0xFFE31C58),
    scarfColor: Color(0xFFE31C58),
    glideBonusMultiplier: 1.08,
    carvingMultiplier: 1.16,
    jumpBoostMultiplier: 1.10,
    scoreMultiplier: 1.25,
    blossomMagnetMeters: 2.9,
  ),
  neoBlossom(
    id: 'neo_blossom',
    name: 'Vivienne LV_NEO Blossom',
    blendPath: 'models/vivienne_lv_neo_blossom.blend',
    heroAssetPath: 'assets/sprites/vivienne_neo_blossom_hero.png',
    subtitle: 'Rose Sakura & Skis / Écharpe Cobalt LV_NEO',
    perkLabel: 'Aimant Fleurs Blossom +45 % • Score ×1.15',
    petalColor: Color(0xFFF3B7C3),
    trimEdgeColor: Color(0xFF1638E8),
    stitchGoldColor: Color(0xFFFFE082),
    eyeFlowerColor: Color(0xFF1638E8),
    motifColor: Color(0xFFFFF0F5),
    skiDeckColor: Color(0xFF1638E8),
    skiAccentColor: Color(0xFFF3B7C3),
    scarfColor: Color(0xFF1638E8),
    glideBonusMultiplier: 1.05,
    carvingMultiplier: 1.10,
    jumpBoostMultiplier: 1.07,
    scoreMultiplier: 1.15,
    blossomMagnetMeters: 3.4,
  );

  const VivienneSkiEdition({
    required this.id,
    required this.name,
    required this.blendPath,
    required this.heroAssetPath,
    required this.subtitle,
    required this.perkLabel,
    required this.petalColor,
    required this.trimEdgeColor,
    required this.stitchGoldColor,
    required this.eyeFlowerColor,
    required this.motifColor,
    required this.skiDeckColor,
    required this.skiAccentColor,
    required this.scarfColor,
    required this.glideBonusMultiplier,
    required this.carvingMultiplier,
    required this.jumpBoostMultiplier,
    required this.scoreMultiplier,
    required this.blossomMagnetMeters,
  });

  final String id;
  final String name;
  final String blendPath;
  final String heroAssetPath;
  final String subtitle;
  final String perkLabel;
  final Color petalColor;
  final Color trimEdgeColor;
  final Color stitchGoldColor;
  final Color eyeFlowerColor;
  final Color motifColor;
  final Color skiDeckColor;
  final Color skiAccentColor;
  final Color scarfColor;
  final double glideBonusMultiplier;
  final double carvingMultiplier;
  final double jumpBoostMultiplier;
  final double scoreMultiplier;
  final double blossomMagnetMeters;
}

/// Real-time 3D Ski Animation States of Vivienne seen from behind (`180°` & `135°..225°`).
enum VivienneSkiAnimState {
  glidingRearNeutral(
    label: 'SCHUSS ROYAL 180°',
    scaleX: 1.00,
    scaleY: 1.00,
    armRaiseFactor: 0.08,
    badgeColor: Color(0xFF29B6F6),
  ),
  carvingLeft(
    label: 'CARVING GAUCHE',
    scaleX: 1.03,
    scaleY: 0.97,
    armRaiseFactor: 0.20,
    badgeColor: Color(0xFF00E676),
  ),
  carvingRight(
    label: 'CARVING DROITE',
    scaleX: 1.03,
    scaleY: 0.97,
    armRaiseFactor: 0.20,
    badgeColor: Color(0xFF00E676),
  ),
  mogulAbsorptionSquash(
    label: 'BOSSE SQUASH !',
    scaleX: 1.12,
    scaleY: 0.80,
    armRaiseFactor: 0.28,
    badgeColor: Color(0xFFFFB300),
  ),
  rampLaunchStretch(
    label: 'IMPULSION TREMPLIN !',
    scaleX: 0.92,
    scaleY: 1.16,
    armRaiseFactor: 0.72,
    badgeColor: Color(0xFFFF9100),
  ),
  airborneCelebration(
    label: 'GRAND SAUT BRAS EN V !',
    scaleX: 0.96,
    scaleY: 1.08,
    armRaiseFactor: 1.00,
    badgeColor: Color(0xFFFF4081),
  ),
  landingImpact(
    label: 'RÉCEPTION POUDREUSE !',
    scaleX: 1.11,
    scaleY: 0.81,
    armRaiseFactor: 0.32,
    badgeColor: Color(0xFF80D8FF),
  ),
  snowballCrash(
    label: 'CHUTE BOULE DE NEIGE !',
    scaleX: 1.22,
    scaleY: 0.96,
    armRaiseFactor: 0.90,
    badgeColor: Color(0xFFFF5252),
  ),
  obstacleStumble(
    label: 'REBOND SAPIN !',
    scaleX: 1.08,
    scaleY: 0.88,
    armRaiseFactor: 0.48,
    badgeColor: Color(0xFFFF5252),
  );

  const VivienneSkiAnimState({
    required this.label,
    required this.scaleX,
    required this.scaleY,
    required this.armRaiseFactor,
    required this.badgeColor,
  });

  final String label;
  final double scaleX;
  final double scaleY;
  final double armRaiseFactor;
  final Color badgeColor;
}

/// Aerial ski figures performed by Vivienne during `airborneCelebration`.
enum SkiAerialTrickKind {
  victoryVArms('V-ARMS ROYAL', 180),
  crossSkiGrab('CROSS-SKI MONOGRAM', 240),
  spreadEagle('SPREAD EAGLE OR', 220),
  blossomSpin360('BLOSSOM SPIN 360°', 320),
  speedyBagGrab('SPEEDY BAG GRAB', 260);

  const SkiAerialTrickKind(this.title, this.bonusPoints);

  final String title;
  final int bonusPoints;
}

/// Optional Blender storyboard pose sprites (`assets/sprites/vivienne_pose_1..6.png`).
enum VivienneBlenderPose {
  pose1Squash('assets/sprites/vivienne_pose_1_squash.png'),
  pose2Launch('assets/sprites/vivienne_pose_2_launch.png'),
  pose3Apex('assets/sprites/vivienne_pose_3_apex.png'),
  pose4Landing('assets/sprites/vivienne_pose_4_landing.png'),
  pose5GrandApex('assets/sprites/vivienne_pose_5_grand_apex.png'),
  pose6Rig('assets/sprites/vivienne_pose_6_rig.png');

  const VivienneBlenderPose(this.assetPath);

  final String assetPath;
}

/// 3D Scenery & Obstacle kinds placed along the ski tracks (`v1.1.0`).
enum SkiPropKind {
  alpinePineTree,
  giantSnowPine,
  crystalIceRock,
  alpineChalet,
  lvBannerPost,
  cableCarPylon,
  cartoonSnowman,
  flutteringPennantPost,
  snowCannon,
  startArch,
  finishArch,
}

@immutable
class SkiWorldProp3D {
  const SkiWorldProp3D({
    required this.id,
    required this.kind,
    required this.x,
    required this.z,
    this.scale = 1.0,
    this.variant = 0,
    this.snowLoad = 1.0,
    this.hitRadius = 1.15,
    this.isOnPiste = false,
  });

  final int id;
  final SkiPropKind kind;
  final double x;
  final double z;
  final double scale;
  final int variant;
  final double snowLoad;
  final double hitRadius;
  final bool isOnPiste;
}

@immutable
class SkiMogul3D {
  const SkiMogul3D({
    required this.id,
    required this.x,
    required this.z,
    this.radiusX = 2.6,
    this.radiusZ = 4.2,
    this.heightMeters = 0.85,
    this.absorbed = false,
  });

  final int id;
  final double x;
  final double z;
  final double radiusX;
  final double radiusZ;
  final double heightMeters;
  final bool absorbed;

  SkiMogul3D copyWith({bool? absorbed}) {
    return SkiMogul3D(
      id: id,
      x: x,
      z: z,
      radiusX: radiusX,
      radiusZ: radiusZ,
      heightMeters: heightMeters,
      absorbed: absorbed ?? this.absorbed,
    );
  }
}

@immutable
class SkiJumpRamp3D {
  const SkiJumpRamp3D({
    required this.id,
    required this.x,
    required this.z,
    this.width = 5.6,
    this.length = 9.5,
    this.heightMeters = 1.65,
    this.boostVy = 11.8,
    this.label = 'TREMPLIN BLOSSOM',
    this.triggered = false,
  });

  final int id;
  final double x;
  final double z;
  final double width;
  final double length;
  final double heightMeters;
  final double boostVy;
  final String label;
  final bool triggered;

  SkiJumpRamp3D copyWith({bool? triggered}) {
    return SkiJumpRamp3D(
      id: id,
      x: x,
      z: z,
      width: width,
      length: length,
      heightMeters: heightMeters,
      boostVy: boostVy,
      label: label,
      triggered: triggered ?? this.triggered,
    );
  }
}

@immutable
class SkiSlalomGate3D {
  const SkiSlalomGate3D({
    required this.id,
    required this.centerX,
    required this.z,
    this.halfWidth = 4.0,
    this.isGoldRed = true,
    this.passed = false,
    this.missed = false,
  });

  final int id;
  final double centerX;
  final double z;
  final double halfWidth;
  final bool isGoldRed;
  final bool passed;
  final bool missed;

  SkiSlalomGate3D copyWith({bool? passed, bool? missed}) {
    return SkiSlalomGate3D(
      id: id,
      centerX: centerX,
      z: z,
      halfWidth: halfWidth,
      isGoldRed: isGoldRed,
      passed: passed ?? this.passed,
      missed: missed ?? this.missed,
    );
  }
}

@immutable
class SkiBlossomCollectible3D {
  const SkiBlossomCollectible3D({
    required this.id,
    required this.x,
    required this.y,
    required this.z,
    this.isStarGold = false,
    this.points = 60,
    this.phaseOffset = 0.0,
    this.collected = false,
  });

  final int id;
  final double x;
  final double y;
  final double z;
  final bool isStarGold;
  final int points;
  final double phaseOffset;
  final bool collected;

  SkiBlossomCollectible3D copyWith({bool? collected}) {
    return SkiBlossomCollectible3D(
      id: id,
      x: x,
      y: y,
      z: z,
      isStarGold: isStarGold,
      points: points,
      phaseOffset: phaseOffset,
      collected: collected ?? this.collected,
    );
  }
}

@immutable
class SkiSnowParticle3D {
  const SkiSnowParticle3D({
    required this.x,
    required this.y,
    required this.z,
    required this.vx,
    required this.vy,
    required this.vz,
    required this.size,
    required this.life,
    required this.maxLife,
    this.color = Colors.white,
    this.isPowderSpray = false,
  });

  final double x;
  final double y;
  final double z;
  final double vx;
  final double vy;
  final double vz;
  final double size;
  final double life;
  final double maxLife;
  final Color color;
  final bool isPowderSpray;

  double get normalizedLife => (life / maxLife).clamp(0.0, 1.0);
}

@immutable
class SkiTrackRibbonPoint {
  const SkiTrackRibbonPoint({
    required this.z,
    required this.centerX,
    required this.elevationY,
    required this.halfWidth,
    required this.leftSkiX,
    required this.rightSkiX,
    this.hasSkiMarks = true,
    this.carveIntensity = 0.0,
  });

  final double z;
  final double centerX;
  final double elevationY;
  final double halfWidth;
  final double leftSkiX;
  final double rightSkiX;
  final bool hasSkiMarks;
  final double carveIntensity;
}

@immutable
class SkiFloatingCallout {
  const SkiFloatingCallout({
    required this.text,
    required this.color,
    required this.life,
    required this.maxLife,
  });

  final String text;
  final Color color;
  final double life;
  final double maxLife;

  double get progress => 1.0 - (life / maxLife).clamp(0.0, 1.0);
}

@immutable
class SkiScoreBreakdown {
  const SkiScoreBreakdown({
    required this.distancePoints,
    required this.blossomPoints,
    required this.slalomPoints,
    required this.jumpAndMogulPoints,
    required this.chronoBonusPoints,
    required this.editionMultiplier,
    required this.totalScore,
    required this.starsEarned,
    required this.elapsedSeconds,
    required this.blossomsCollected,
    required this.slalomPassed,
    required this.jumpsCompleted,
    required this.mogulsAbsorbed,
    required this.maxJumpHeightMeters,
  });

  final int distancePoints;
  final int blossomPoints;
  final int slalomPoints;
  final int jumpAndMogulPoints;
  final int chronoBonusPoints;
  final double editionMultiplier;
  final int totalScore;
  final int starsEarned;
  final double elapsedSeconds;
  final int blossomsCollected;
  final int slalomPassed;
  final int jumpsCompleted;
  final int mogulsAbsorbed;
  final double maxJumpHeightMeters;
}

@immutable
class SkiHighscoreEntry {
  const SkiHighscoreEntry({
    required this.id,
    required this.playerName,
    required this.trackId,
    required this.edition,
    required this.score,
    required this.timeSeconds,
    required this.maxJumpMeters,
    required this.blossomsCollected,
    required this.slalomPassed,
    required this.stars,
    this.isPlayerRun = false,
  });

  final String id;
  final String playerName;
  final SkiTrackId trackId;
  final VivienneSkiEdition edition;
  final int score;
  final double timeSeconds;
  final double maxJumpMeters;
  final int blossomsCollected;
  final int slalomPassed;
  final int stars;
  final bool isPlayerRun;
}

/// 360° Cycles Turntable specification (`assets/turntable/vivienne_turntable_00..23.png`).
///
/// Frame `00` = `0°` Front View
/// Frame `12` = `180°` Rear View (Back of Vivienne for 3rd-person skiing!)
/// Frames `09..11` = `135°..165°` Rear-Left Carving Views
/// Frames `13..15` = `195°..225°` Rear-Right Carving Views
@immutable
class VivienneTurntableSpec {
  const VivienneTurntableSpec._();

  static const int frameCount = 24;
  static const double degreesPerFrame = 360.0 / frameCount; // 15.0°
  static const int rearNeutralFrameIndex = 12; // 180° Dos

  static String assetPathForIndex(int index) {
    final int normalized = ((index % frameCount) + frameCount) % frameCount;
    final String twoDigits = normalized.toString().padLeft(2, '0');
    return 'assets/turntable/vivienne_turntable_$twoDigits.png';
  }

  static int frameIndexForAngle(double angleDegrees) {
    final double norm = ((angleDegrees % 360.0) + 360.0) % 360.0;
    return ((norm / degreesPerFrame).round()) % frameCount;
  }

  /// Maps lateral carving input `carveTilt` in `[-1.0, 1.0]` to rear Cycles sprites `09..15`:
  /// - `0.0` -> `12` (`180°` Rear Neutral)
  /// - `< 0.0` (Left carve) -> `11` (`165°`), `10` (`150°`), `09` (`135°`)
  /// - `> 0.0` (Right carve) -> `13` (`195°`), `14` (`210°`), `15` (`225°`)
  static int rearCarvingFrameIndex(double carveTilt) {
    final double clamped = carveTilt.clamp(-1.0, 1.0);
    final int offset = (clamped * 2.4).round().clamp(-3, 3);
    return rearNeutralFrameIndex + offset;
  }

  static String angleLabelForDegrees(double angleDegrees) {
    final double norm = ((angleDegrees % 360.0) + 360.0) % 360.0;
    if (norm < 22.5 || norm >= 337.5) {
      return 'Vue de Face (0°) • Corolle Blossom & Œil Monogram';
    } else if (norm < 67.5) {
      return 'Vue 3/4 Face Gauche (45°) • Pétales Vachetta & Carmin';
    } else if (norm < 112.5) {
      return 'Profil Gauche (90°) • Galbe Cuir & Surpiqûre Jaune';
    } else if (norm < 157.5) {
      return 'Carving Gauche (135°–150°) • Vue 3/4 Dos Gauche';
    } else if (norm < 202.5) {
      return 'Schuss Vue de Dos (180°) • Chêne Monogram & Mini Speedy';
    } else if (norm < 247.5) {
      return 'Carving Droite (210°–225°) • Vue 3/4 Dos Droit';
    } else if (norm < 292.5) {
      return 'Profil Droit (270°) • Mini Sac Speedy LV Suspendu';
    } else {
      return 'Vue 3/4 Face Droit (315°) • Rivets Or 24K & Speedy';
    }
  }
}
