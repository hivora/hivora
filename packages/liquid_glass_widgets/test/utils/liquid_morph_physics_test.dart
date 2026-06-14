import 'package:flutter_test/flutter_test.dart';

import 'package:liquid_glass_widgets/utils/liquid_morph_physics.dart';

// ─── Helpers ───────────────────────────────────────────────────────────────

/// Standard geometry used across most tests.
const double _finalDx = 80.0;
const double _finalDy = 160.0;
const double _hOffset = 8.0;
const double _vOffset = 4.0;

LiquidMorphState _compute(
  double rawValue, {
  double finalDx = _finalDx,
  double finalDy = _finalDy,
  double horizontalOffset = _hOffset,
  double verticalOffset = _vOffset,
}) =>
    LiquidMorphPhysics.compute(
      rawValue: rawValue,
      finalDx: finalDx,
      finalDy: finalDy,
      horizontalOffset: horizontalOffset,
      verticalOffset: verticalOffset,
    );

void main() {
  // ── Resting state ─────────────────────────────────────────────────────────

  group('LiquidMorphPhysics — resting state (rawValue = 0.0)', () {
    late LiquidMorphState s;
    setUp(() => s = _compute(0.0));

    test('pathT is 0.0 at rest', () => expect(s.pathT, equals(0.0)));
    test('sizeT is 0.0 at rest', () => expect(s.sizeT, equals(0.0)));
    test('currentDx is 0.0 at rest', () => expect(s.currentDx, equals(0.0)));
    test('currentDy is 0.0 at rest', () => expect(s.currentDy, equals(0.0)));
    test('pushDx is 0.0 at rest (no close undershoot)', () {
      expect(s.pushDx, equals(0.0));
    });
    test('pushDy is 0.0 at rest (no close undershoot)', () {
      expect(s.pushDy, equals(0.0));
    });
    test('anchorScale is 1.0 at rest', () {
      expect(s.anchorScale, equals(1.0));
    });
    test('containerScale is 1.0 at rest', () {
      expect(s.containerScale, equals(1.0));
    });
    test('blend is 0.0 at rest (no separation)', () {
      expect(s.blend, equals(0.0));
    });
    test('phase is idle at rest', () {
      expect(s.phase, equals(MorphPhase.idle));
    });
  });

  // ── Fully settled state ───────────────────────────────────────────────────

  group('LiquidMorphPhysics — fully settled (rawValue = 1.0)', () {
    late LiquidMorphState s;
    setUp(() => s = _compute(1.0));

    test('anchorScale is 0.0 when fully open', () {
      expect(s.anchorScale, equals(0.0));
    });
    test('containerScale is 1.0 in normal travel range', () {
      expect(s.containerScale, equals(1.0));
    });
    test('currentDx equals finalDx * pathT', () {
      expect(s.currentDx, closeTo(_finalDx * s.pathT, 0.001));
    });
    test('phase is settled at rawValue = 1.0', () {
      expect(s.phase, equals(MorphPhase.settled));
    });
    test('pushDx is 0 when rawValue >= 0 (no close undershoot)', () {
      expect(s.pushDx, equals(0.0));
    });
  });

  // ── Phase transitions ─────────────────────────────────────────────────────

  group('LiquidMorphPhysics — phase state machine', () {
    test('0.001 → detaching', () {
      expect(_compute(0.001).phase, equals(MorphPhase.detaching));
    });
    test('0.1 → detaching', () {
      expect(_compute(0.1).phase, equals(MorphPhase.detaching));
    });
    test('0.4 → travelling', () {
      expect(_compute(0.4).phase, equals(MorphPhase.travelling));
    });
    test('0.6 → travelling', () {
      expect(_compute(0.6).phase, equals(MorphPhase.travelling));
    });
    test('0.8 → arriving', () {
      expect(_compute(0.8).phase, equals(MorphPhase.arriving));
    });
    test('0.99 → arriving (just below settled threshold)', () {
      expect(_compute(0.99).phase, equals(MorphPhase.arriving));
    });
    test('1.0 → settled', () {
      expect(_compute(1.0).phase, equals(MorphPhase.settled));
    });
    test('negative rawValue → detaching (close bounce)', () {
      expect(_compute(-0.1).phase, equals(MorphPhase.detaching));
    });
  });

  // ── Close undershoot (rawValue < 0) ───────────────────────────────────────

  group('LiquidMorphPhysics — close undershoot (rawValue < 0)', () {
    const undershoot = -0.2;
    late LiquidMorphState s;
    setUp(() => s = _compute(undershoot));

    test('containerScale drops below 1.0 during close undershoot', () {
      // 1.0 + (-0.2 * 0.55) = 0.89
      expect(s.containerScale, lessThan(1.0));
      expect(s.containerScale, closeTo(1.0 + undershoot * 0.55, 0.001));
    });

    test('pushDx is non-zero during close undershoot', () {
      // pushDx = (finalDx + horizontalOffset) * rawValue
      final expected = (_finalDx + _hOffset) * undershoot;
      expect(s.pushDx, closeTo(expected, 0.001));
    });

    test('pushDy is non-zero during close undershoot', () {
      final expected = (_finalDy + _vOffset) * undershoot;
      expect(s.pushDy, closeTo(expected, 0.001));
    });

    test('pathT includes closeUndershoot additive term', () {
      // clampedValue = 0 → backOutCurve(0) = 0, closeUndershoot = -0.2
      // pathT = 0 + (-0.2) = -0.2
      expect(s.pathT, closeTo(-0.2, 0.001));
    });

    test('sizeT includes closeUndershoot additive term', () {
      // clampedValue = 0 → linearToEaseOut(0) = 0, closeUndershoot = -0.2
      // sizeT = 0 + (-0.2) = -0.2
      expect(s.sizeT, closeTo(-0.2, 0.001));
    });

    test('containerScale clamps correctly for extreme undershoot', () {
      // rawValue = -1.0 → scale = 1.0 + (-1.0 * 0.55) = 0.45
      final extreme = _compute(-1.0);
      expect(extreme.containerScale, closeTo(0.45, 0.001));
    });
  });

  // ── Open overshoot (rawValue > 1) ─────────────────────────────────────────

  group('LiquidMorphPhysics — open overshoot (rawValue > 1)', () {
    const overshoot = 1.05;
    late LiquidMorphState s;
    setUp(() => s = _compute(overshoot));

    test('containerScale slightly above 1.0 during open overshoot', () {
      // 1.0 + (0.05 * 0.10) = 1.005
      expect(s.containerScale, greaterThan(1.0));
      expect(s.containerScale, closeTo(1.0 + (overshoot - 1.0) * 0.10, 0.001));
    });

    test('pushDx is 0 during open overshoot (positive rawValue)', () {
      expect(s.pushDx, equals(0.0));
    });

    test('pushDy is 0 during open overshoot', () {
      expect(s.pushDy, equals(0.0));
    });

    test('phase is settled for overshoot (rawValue >= 1)', () {
      expect(s.phase, equals(MorphPhase.settled));
    });
  });

  // ── Anchor scale ──────────────────────────────────────────────────────────

  group('LiquidMorphPhysics — anchorScale', () {
    test('is 1.0 at rawValue = 0.0 (trigger fully visible)', () {
      expect(_compute(0.0).anchorScale, equals(1.0));
    });

    test('is 0.5 at rawValue = 0.2 (halfway through 40% ease)', () {
      // (1 - 0.2/0.4).clamp(0,1) = 0.5
      expect(_compute(0.2).anchorScale, closeTo(0.5, 0.001));
    });

    test('is 0.0 at rawValue = 0.4 (fully detached)', () {
      expect(_compute(0.4).anchorScale, closeTo(0.0, 0.001));
    });

    test('stays 0.0 for rawValue > 0.4', () {
      expect(_compute(0.6).anchorScale, equals(0.0));
      expect(_compute(1.0).anchorScale, equals(0.0));
    });

    test('grows back toward 1.0 as rawValue returns to 0 on close', () {
      final atClose = _compute(0.2);
      expect(atClose.anchorScale, closeTo(0.5, 0.001));
    });
  });

  // ── Blob B displacement ───────────────────────────────────────────────────

  group('LiquidMorphPhysics — Blob B displacement', () {
    test('currentDx = finalDx * pathT', () {
      final s = _compute(0.5);
      expect(s.currentDx, closeTo(_finalDx * s.pathT, 0.001));
    });

    test('currentDy = finalDy * pathT', () {
      final s = _compute(0.5);
      expect(s.currentDy, closeTo(_finalDy * s.pathT, 0.001));
    });

    test('finalDx = 0 → currentDx always 0 regardless of rawValue', () {
      for (final v in [0.0, 0.3, 0.7, 1.0]) {
        expect(
          _compute(v, finalDx: 0.0, finalDy: _finalDy).currentDx,
          equals(0.0),
          reason: 'rawValue=$v',
        );
      }
    });
  });

  // ── Blend (metaball merge intensity) ─────────────────────────────────────

  group('LiquidMorphPhysics — blend', () {
    test('blend is 0.0 at rest', () {
      expect(_compute(0.0).blend, equals(0.0));
    });

    test('blend is near-zero when fully settled (pathT ≈ sizeT ≈ 1.0)', () {
      expect(_compute(1.0).blend, lessThan(2.0));
    });

    test('blend is non-zero during mid-travel (separation between curves)', () {
      final s = _compute(0.5);
      expect(s.blend, greaterThan(0.0));
    });

    test('blend is clamped to a maximum of 28.0', () {
      for (int i = 0; i <= 100; i++) {
        final raw = i / 100.0;
        expect(
          _compute(raw).blend,
          lessThanOrEqualTo(28.0),
          reason: 'rawValue=$raw exceeded max blend',
        );
      }
    });

    test('blend is always non-negative', () {
      for (final v in [-0.3, 0.0, 0.25, 0.5, 0.75, 1.0, 1.1]) {
        expect(
          _compute(v).blend,
          greaterThanOrEqualTo(0.0),
          reason: 'rawValue=$v produced negative blend',
        );
      }
    });
  });

  // ── Spring constants (public contract) ───────────────────────────────────

  group('LiquidMorphPhysics — spring constants', () {
    test('openSpring has stiffness 120', () {
      expect(LiquidMorphPhysics.openSpring.stiffness, equals(120.0));
    });

    test('openSpring has damping 16', () {
      expect(LiquidMorphPhysics.openSpring.damping, equals(16.0));
    });

    test('closeSpring has same profile as openSpring', () {
      expect(LiquidMorphPhysics.closeSpring.stiffness,
          equals(LiquidMorphPhysics.openSpring.stiffness));
      expect(LiquidMorphPhysics.closeSpring.damping,
          equals(LiquidMorphPhysics.openSpring.damping));
    });

    test('closeVelocityHint is negative (drives spring toward 0 with momentum)',
        () {
      expect(LiquidMorphPhysics.closeVelocityHint, lessThan(0.0));
    });
  });

  // ── Geometry scaling ──────────────────────────────────────────────────────

  group('LiquidMorphPhysics — geometry scaling', () {
    test('doubling finalDx doubles currentDx at same rawValue', () {
      const v = 0.6;
      final s1 = _compute(v, finalDx: 100.0, finalDy: 0.0);
      final s2 = _compute(v, finalDx: 200.0, finalDy: 0.0);
      expect(s2.currentDx, closeTo(s1.currentDx * 2.0, 0.01));
    });

    test('doubling finalDy doubles currentDy at same rawValue', () {
      const v = 0.6;
      final s1 = _compute(v, finalDx: 0.0, finalDy: 100.0);
      final s2 = _compute(v, finalDx: 0.0, finalDy: 200.0);
      expect(s2.currentDy, closeTo(s1.currentDy * 2.0, 0.01));
    });

    test('horizontalOffset only affects pushDx (not currentDx)', () {
      const v = -0.1;
      final s1 = _compute(
        v,
        finalDx: 100.0,
        finalDy: 0.0,
        horizontalOffset: 0.0,
      );
      final s2 = _compute(
        v,
        finalDx: 100.0,
        finalDy: 0.0,
        horizontalOffset: 20.0,
      );
      // currentDx comes from finalDx * pathT — offset does NOT affect it.
      expect(s1.currentDx, closeTo(s2.currentDx, 0.001));
      // pushDx IS affected by horizontalOffset.
      expect(s2.pushDx, isNot(closeTo(s1.pushDx, 0.001)));
    });
  });

  // ── Monotonicity / smoothness smoke-test ──────────────────────────────────

  group('LiquidMorphPhysics — animation smoothness', () {
    test('sizeT increases monotonically from 0 to 1 during open', () {
      double prev = -1.0;
      for (int i = 0; i <= 100; i++) {
        final raw = i / 100.0;
        final cur = _compute(raw).sizeT;
        expect(cur, greaterThanOrEqualTo(prev),
            reason: 'sizeT not monotonic at rawValue=$raw');
        prev = cur;
      }
    });

    test('anchorScale decreases monotonically from 1.0 to 0.0 over [0, 0.4]',
        () {
      double prev = 1.1;
      for (int i = 0; i <= 40; i++) {
        final raw = i / 100.0; // 0.00 → 0.40
        final cur = _compute(raw).anchorScale;
        expect(cur, lessThanOrEqualTo(prev),
            reason:
                'anchorScale not monotonically decreasing at rawValue=$raw');
        prev = cur;
      }
    });

    test('containerScale is exactly 1.0 throughout normal travel [0, 1]', () {
      for (int i = 0; i <= 100; i++) {
        final raw = i / 100.0;
        expect(
          _compute(raw).containerScale,
          equals(1.0),
          reason: 'containerScale ≠ 1.0 at rawValue=$raw',
        );
      }
    });
  });
}
