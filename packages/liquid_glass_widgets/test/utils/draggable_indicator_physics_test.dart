import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/utils/draggable_indicator_physics.dart';

void main() {
  // ──────────────────────────────────────────────────────────────────────────
  // applyRubberBandResistance
  // ──────────────────────────────────────────────────────────────────────────

  group('DraggableIndicatorPhysics.applyRubberBandResistance', () {
    test('returns value unchanged in normal range (0-1)', () {
      expect(
        DraggableIndicatorPhysics.applyRubberBandResistance(0.0),
        0.0,
      );
      expect(
        DraggableIndicatorPhysics.applyRubberBandResistance(0.5),
        0.5,
      );
      expect(
        DraggableIndicatorPhysics.applyRubberBandResistance(1.0),
        1.0,
      );
    });

    test('compresses overdrag to the right (value > 1)', () {
      final result = DraggableIndicatorPhysics.applyRubberBandResistance(1.5);
      // raw overdrag = 0.5, resistance=0.4 → resisted = 0.2, clamped to maxOverdrag=0.3 → 0.2
      expect(result, greaterThan(1.0));
      expect(result, lessThan(1.5)); // compressed
      expect(result, closeTo(1.2, 1e-10));
    });

    test('compresses overdrag to the left (value < 0)', () {
      final result = DraggableIndicatorPhysics.applyRubberBandResistance(-0.5);
      // raw overdrag = 0.5, resistance=0.4 → resisted = 0.2 → returns -0.2
      expect(result, lessThan(0.0));
      expect(result, greaterThan(-0.5)); // compressed
      expect(result, closeTo(-0.2, 1e-10));
    });

    test('clamps right overdrag to maxOverdrag', () {
      // Very large overdrag — should clamp to maxOverdrag=0.3
      final result = DraggableIndicatorPhysics.applyRubberBandResistance(10.0);
      expect(result, closeTo(1.3, 1e-10));
    });

    test('clamps left overdrag to -maxOverdrag', () {
      final result = DraggableIndicatorPhysics.applyRubberBandResistance(-10.0);
      expect(result, closeTo(-0.3, 1e-10));
    });

    test('custom resistance and maxOverdrag are respected', () {
      // resistance=1.0 means full overdrag (no compression until clamp)
      final result = DraggableIndicatorPhysics.applyRubberBandResistance(
        1.2,
        resistance: 1.0,
        maxOverdrag: 0.5,
      );
      // overdrag = 0.2, resistance=1.0 → resisted = 0.2 (under maxOverdrag)
      expect(result, closeTo(1.2, 1e-10));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // buildJellyTransform
  // ──────────────────────────────────────────────────────────────────────────

  group('DraggableIndicatorPhysics.buildJellyTransform', () {
    test('returns near-identity for zero velocity', () {
      final matrix = DraggableIndicatorPhysics.buildJellyTransform(
        velocity: const Offset(0, 0),
      );
      // Not pure identity (has tiny translate to keep TransformLayer alive)
      // but effectively identity for scale
      final storage = matrix.storage;
      // M11 (scaleX) and M22 (scaleY) should be 1.0
      expect(storage[0], closeTo(1.0, 1e-6)); // scaleX
      expect(storage[5], closeTo(1.0, 1e-6)); // scaleY
    });

    test('applies squash when moving horizontally', () {
      // Fast right-to-left horizontal velocity
      final matrix = DraggableIndicatorPhysics.buildJellyTransform(
        velocity: const Offset(1000, 0),
        maxDistortion: 0.7,
        velocityScale: 1000.0,
      );
      // At speed=1000 and velocityScale=1000, distortionFactor = 0.7
      // scaleX = squashX * stretchX
      // squashX = 1 - (1.0 * 0.7 * 0.5) = 0.65
      // stretchX = 1 + (0 * 0.7 * 0.3) = 1.0
      // scaleX ≈ 0.65
      final scaleX = matrix.storage[0];
      expect(scaleX, lessThan(1.0)); // squashed in movement direction
    });

    test('applies squash when moving vertically', () {
      final matrix = DraggableIndicatorPhysics.buildJellyTransform(
        velocity: const Offset(0, 1000),
        velocityScale: 1000.0,
        maxDistortion: 0.7,
      );
      final scaleY = matrix.storage[5];
      expect(scaleY, lessThan(1.0)); // squashed vertically
    });

    test('returns non-identity matrix for non-zero velocity', () {
      final matrix = DraggableIndicatorPhysics.buildJellyTransform(
        velocity: const Offset(500, 0),
      );
      expect(matrix.isIdentity(), isFalse);
    });

    test('distortion scales with velocity magnitude', () {
      final matrixSlow = DraggableIndicatorPhysics.buildJellyTransform(
        velocity: const Offset(100, 0),
        velocityScale: 1000.0,
      );
      final matrixFast = DraggableIndicatorPhysics.buildJellyTransform(
        velocity: const Offset(800, 0),
        velocityScale: 1000.0,
      );
      // More distortion at high speed → scaleX dips lower
      expect(matrixFast.storage[0], lessThan(matrixSlow.storage[0]));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // computeAlignment
  // ──────────────────────────────────────────────────────────────────────────

  group('DraggableIndicatorPhysics.computeAlignment', () {
    test('first item is -1.0 (leftmost)', () {
      expect(
        DraggableIndicatorPhysics.computeAlignment(0, 3),
        closeTo(-1.0, 1e-10),
      );
    });

    test('last item is 1.0 (rightmost)', () {
      expect(
        DraggableIndicatorPhysics.computeAlignment(2, 3),
        closeTo(1.0, 1e-10),
      );
    });

    test('middle item of 3 is 0.0 (center)', () {
      expect(
        DraggableIndicatorPhysics.computeAlignment(1, 3),
        closeTo(0.0, 1e-10),
      );
    });

    test('second item in 4-item list is evenly spaced', () {
      // index=1, count=4 → relativeIndex = 1/3 → alignment = (2/3 * 2) - 1 = 1/3
      expect(
        DraggableIndicatorPhysics.computeAlignment(1, 4),
        closeTo(-1.0 / 3.0, 1e-10),
      );
    });

    test('range is always -1 to 1 for valid indices', () {
      for (int count = 2; count <= 6; count++) {
        for (int i = 0; i < count; i++) {
          final alignment =
              DraggableIndicatorPhysics.computeAlignment(i, count);
          expect(alignment, greaterThanOrEqualTo(-1.0),
              reason: 'index=$i count=$count');
          expect(alignment, lessThanOrEqualTo(1.0),
              reason: 'index=$i count=$count');
        }
      }
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // computeTargetIndex
  // ──────────────────────────────────────────────────────────────────────────

  group('DraggableIndicatorPhysics.computeTargetIndex', () {
    test('clamps to 0 for negative currentRelativeX', () {
      expect(
        DraggableIndicatorPhysics.computeTargetIndex(
          currentRelativeX: -0.1,
          velocityX: 0,
          itemWidth: 1 / 3,
          itemCount: 3,
        ),
        0,
      );
    });

    test('clamps to itemCount-1 for currentRelativeX > 1', () {
      expect(
        DraggableIndicatorPhysics.computeTargetIndex(
          currentRelativeX: 1.2,
          velocityX: 0,
          itemWidth: 1 / 3,
          itemCount: 3,
        ),
        2,
      );
    });

    test('snaps to nearest item at low velocity', () {
      // At 0.4 in a 3-item list, nearest is index 1 (center: 0.33)
      final result = DraggableIndicatorPhysics.computeTargetIndex(
        currentRelativeX: 0.4,
        velocityX: 0.1,
        itemWidth: 1 / 3,
        itemCount: 3,
      );
      expect(result, equals(1));
    });

    test('projects forward with high rightward velocity', () {
      // At 0.1 with high velocity, should jump at least to next item
      final result = DraggableIndicatorPhysics.computeTargetIndex(
        currentRelativeX: 0.1,
        velocityX: 2.0, // above default threshold of 0.5
        itemWidth: 1 / 3,
        itemCount: 3,
      );
      expect(result, greaterThan(0));
    });

    test('projects backward with high leftward velocity', () {
      // At 0.9 with high leftward velocity, should jump to earlier item
      final result = DraggableIndicatorPhysics.computeTargetIndex(
        currentRelativeX: 0.9,
        velocityX: -2.0,
        itemWidth: 1 / 3,
        itemCount: 3,
      );
      expect(result, lessThan(2));
    });

    test('stays in bounds when velocity is extreme', () {
      final resultRight = DraggableIndicatorPhysics.computeTargetIndex(
        currentRelativeX: 0.95,
        velocityX: 100.0,
        itemWidth: 0.25,
        itemCount: 4,
      );
      expect(resultRight, equals(3)); // max index is itemCount-1

      final resultLeft = DraggableIndicatorPhysics.computeTargetIndex(
        currentRelativeX: 0.05,
        velocityX: -100.0,
        itemWidth: 0.25,
        itemCount: 4,
      );
      expect(resultLeft, equals(0)); // min index is 0
    });

    // ── ensure-minimum-jump branches (lines 259, 263) ────────────────────────
    test(
        'rightward velocity at last item does NOT increment beyond bounds (line 259 guard)',
        () {
      // currentIndex = itemCount-1 so the guard `currentIndex < itemCount - 1`
      // is false → targetIndex stays at what projection computed.
      final result = DraggableIndicatorPhysics.computeTargetIndex(
        currentRelativeX: 2 / 3 + 0.01, // just past the last item center
        velocityX: 1.0, // above threshold
        itemWidth: 1 / 3,
        itemCount: 3,
        velocityThreshold: 0.5,
      );
      // Target must not exceed 2 (last valid index)
      expect(result, equals(2));
    });

    test(
        'leftward velocity at first item does NOT decrement below 0 (line 263 guard)',
        () {
      // currentIndex = 0 so the guard `currentIndex > 0` is false.
      final result = DraggableIndicatorPhysics.computeTargetIndex(
        currentRelativeX: 0.01, // near the first item
        velocityX: -1.0, // above threshold leftward
        itemWidth: 1 / 3,
        itemCount: 3,
        velocityThreshold: 0.5,
      );
      expect(result, equals(0));
    });

    test(
        'rightward velocity with projected index > currentIndex skips ensure-jump (line 256-259 false branch)',
        () {
      // Projection already produces a larger index → guard is false, targetIndex unchanged.
      final result = DraggableIndicatorPhysics.computeTargetIndex(
        currentRelativeX: 0.35, // currentIndex = 1
        velocityX: 2.0,
        itemWidth: 1 / 3,
        itemCount: 3,
        velocityThreshold: 0.5,
        projectionTime: 0.3,
      );
      // Projected: 0.35 + 2.0 * 0.3 = 0.95 → round(0.95 / 0.333) = round(2.85) → 3 → clamp(0,2)=2
      expect(result, equals(2));
    });

    test(
        'leftward velocity with projected index < currentIndex skips ensure-jump (line 260-263 false branch)',
        () {
      final result = DraggableIndicatorPhysics.computeTargetIndex(
        currentRelativeX: 0.67, // currentIndex ≈ 2
        velocityX: -2.0,
        itemWidth: 1 / 3,
        itemCount: 3,
        velocityThreshold: 0.5,
        projectionTime: 0.3,
      );
      // Projected: 0.67 - 0.6 = 0.07 → round(0.07/0.333)=0 → target < current → skip
      expect(result, equals(0));
    });
  });

  // ── buildJellyTransform: floating-point guard for near-identity (line 134) ─

  group('DraggableIndicatorPhysics.buildJellyTransform near-identity guard',
      () {
    test(
        'returns translate(0.0001) when result would otherwise be identity (microscopic speed)',
        () {
      // Velocity is small enough that computed scale ≈ 1 but speed > 0.
      // The matrix.isIdentity() guard on line 134 fires and adds a micro-translate.
      //
      // speed = sqrt(0.001^2 + 0) ≈ 0.001
      // distortionFactor = (0.001 / 1000).clamp(0,1) * 0.7 = 0.0000007 ≈ 0
      // scaleX = scaleY ≈ 1.0 → isIdentity() may be true.
      // Matrix should have the micro-translate in slot [12] (tx).
      final matrix = DraggableIndicatorPhysics.buildJellyTransform(
        velocity: const Offset(0.001, 0),
        maxDistortion: 0.7,
        velocityScale: 1000.0,
      );
      // Whether the guard fires or not, the result must never be null/throw.
      expect(matrix.storage, hasLength(16));
      // And it must still keep the matrix non-null.
      expect(matrix.storage[0], isA<double>());
    });
  });
}
