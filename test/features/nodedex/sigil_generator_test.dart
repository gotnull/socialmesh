// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/nodedex/models/nodedex_entry.dart';
import 'package:socialmesh/features/nodedex/services/sigil_generator.dart';

void main() {
  group('SigilGenerator', () {
    group('determinism', () {
      test('same nodeNum always produces identical sigil', () {
        const nodeNum = 0xDEADBEEF;
        final sigil1 = SigilGenerator.generate(nodeNum);
        final sigil2 = SigilGenerator.generate(nodeNum);

        expect(sigil1.vertices, equals(sigil2.vertices));
        expect(sigil1.rotation, equals(sigil2.rotation));
        expect(sigil1.innerRings, equals(sigil2.innerRings));
        expect(sigil1.drawRadials, equals(sigil2.drawRadials));
        expect(sigil1.centerDot, equals(sigil2.centerDot));
        expect(sigil1.symmetryFold, equals(sigil2.symmetryFold));
        expect(sigil1.primaryColor, equals(sigil2.primaryColor));
        expect(sigil1.secondaryColor, equals(sigil2.secondaryColor));
        expect(sigil1.tertiaryColor, equals(sigil2.tertiaryColor));
      });

      test('determinism holds across many node numbers', () {
        final testNodeNums = [0, 1, 255, 1000, 65535, 0x7FFFFFFF, 0xFFFFFFFF];
        for (final nodeNum in testNodeNums) {
          final a = SigilGenerator.generate(nodeNum);
          final b = SigilGenerator.generate(nodeNum);
          expect(
            a.vertices,
            equals(b.vertices),
            reason: 'vertices mismatch for node $nodeNum',
          );
          expect(
            a.primaryColor,
            equals(b.primaryColor),
            reason: 'primaryColor mismatch for node $nodeNum',
          );
        }
      });

      test('colorsFor returns same colors as generate', () {
        const nodeNum = 42;
        final sigil = SigilGenerator.generate(nodeNum);
        final (primary, secondary, tertiary) = SigilGenerator.colorsFor(
          nodeNum,
        );

        expect(primary, equals(sigil.primaryColor));
        expect(secondary, equals(sigil.secondaryColor));
        expect(tertiary, equals(sigil.tertiaryColor));
      });
    });

    group('parameter bounds', () {
      test('vertices are always between 3 and 8', () {
        for (int i = 0; i < 500; i++) {
          final sigil = SigilGenerator.generate(i);
          expect(
            sigil.vertices,
            greaterThanOrEqualTo(3),
            reason: 'vertices too low for node $i',
          );
          expect(
            sigil.vertices,
            lessThanOrEqualTo(8),
            reason: 'vertices too high for node $i',
          );
        }
      });

      test('innerRings are always between 0 and 3', () {
        for (int i = 0; i < 500; i++) {
          final sigil = SigilGenerator.generate(i);
          expect(
            sigil.innerRings,
            greaterThanOrEqualTo(0),
            reason: 'innerRings too low for node $i',
          );
          expect(
            sigil.innerRings,
            lessThanOrEqualTo(3),
            reason: 'innerRings too high for node $i',
          );
        }
      });

      test('symmetryFold is always between 2 and 6', () {
        for (int i = 0; i < 500; i++) {
          final sigil = SigilGenerator.generate(i);
          expect(
            sigil.symmetryFold,
            greaterThanOrEqualTo(2),
            reason: 'symmetryFold too low for node $i',
          );
          expect(
            sigil.symmetryFold,
            lessThanOrEqualTo(6),
            reason: 'symmetryFold too high for node $i',
          );
        }
      });

      test('rotation is between 0 and 2*pi', () {
        const twoPi = 3.14159265358979 * 2.0;
        for (int i = 0; i < 500; i++) {
          final sigil = SigilGenerator.generate(i);
          expect(
            sigil.rotation,
            greaterThanOrEqualTo(0.0),
            reason: 'rotation negative for node $i',
          );
          expect(
            sigil.rotation,
            lessThanOrEqualTo(twoPi),
            reason: 'rotation exceeds 2pi for node $i',
          );
        }
      });

      test('rotation is quantized to 24 steps', () {
        const step = 3.14159265358979 * 2.0 / 24.0;
        for (int i = 0; i < 500; i++) {
          final sigil = SigilGenerator.generate(i);
          final stepIndex = (sigil.rotation / step).round();
          final expectedRotation = stepIndex * step;
          expect(
            sigil.rotation,
            closeTo(expectedRotation, 1e-10),
            reason: 'rotation not quantized for node $i',
          );
        }
      });
    });

    group('visual diversity', () {
      test('sequential node numbers produce different sigils', () {
        final sigil0 = SigilGenerator.generate(0);
        final sigil1 = SigilGenerator.generate(1);

        // At least one visual parameter must differ.
        final hasDifference =
            sigil0.vertices != sigil1.vertices ||
            sigil0.rotation != sigil1.rotation ||
            sigil0.innerRings != sigil1.innerRings ||
            sigil0.drawRadials != sigil1.drawRadials ||
            sigil0.centerDot != sigil1.centerDot ||
            sigil0.symmetryFold != sigil1.symmetryFold ||
            sigil0.primaryColor != sigil1.primaryColor;

        expect(
          hasDifference,
          isTrue,
          reason: 'Node 0 and 1 should produce visually different sigils',
        );
      });

      test('generates variety of vertex counts across 100 nodes', () {
        final vertexCounts = <int>{};
        for (int i = 0; i < 100; i++) {
          vertexCounts.add(SigilGenerator.generate(i).vertices);
        }
        // Should see at least 3 different vertex counts out of 6 possible.
        expect(
          vertexCounts.length,
          greaterThanOrEqualTo(3),
          reason:
              'Expected at least 3 distinct vertex counts, got $vertexCounts',
        );
      });

      test('generates variety of inner ring counts across 100 nodes', () {
        final ringCounts = <int>{};
        for (int i = 0; i < 100; i++) {
          ringCounts.add(SigilGenerator.generate(i).innerRings);
        }
        // Should see at least 2 different ring counts out of 4 possible.
        expect(
          ringCounts.length,
          greaterThanOrEqualTo(2),
          reason: 'Expected at least 2 distinct ring counts, got $ringCounts',
        );
      });

      test('generates both drawRadials true and false across 100 nodes', () {
        bool seenTrue = false;
        bool seenFalse = false;
        for (int i = 0; i < 100; i++) {
          if (SigilGenerator.generate(i).drawRadials) {
            seenTrue = true;
          } else {
            seenFalse = true;
          }
          if (seenTrue && seenFalse) break;
        }
        expect(
          seenTrue && seenFalse,
          isTrue,
          reason: 'Expected both drawRadials=true and false across 100 nodes',
        );
      });

      test('generates both centerDot true and false across 100 nodes', () {
        bool seenTrue = false;
        bool seenFalse = false;
        for (int i = 0; i < 100; i++) {
          if (SigilGenerator.generate(i).centerDot) {
            seenTrue = true;
          } else {
            seenFalse = true;
          }
          if (seenTrue && seenFalse) break;
        }
        expect(
          seenTrue && seenFalse,
          isTrue,
          reason: 'Expected both centerDot=true and false across 100 nodes',
        );
      });
    });

    group('color uniqueness', () {
      test('all three colors are distinct for any node', () {
        for (int i = 0; i < 500; i++) {
          final sigil = SigilGenerator.generate(i);
          expect(
            sigil.primaryColor,
            isNot(equals(sigil.secondaryColor)),
            reason: 'primary == secondary for node $i',
          );
          expect(
            sigil.primaryColor,
            isNot(equals(sigil.tertiaryColor)),
            reason: 'primary == tertiary for node $i',
          );
          expect(
            sigil.secondaryColor,
            isNot(equals(sigil.tertiaryColor)),
            reason: 'secondary == tertiary for node $i',
          );
        }
      });

      test('colors come from the palette', () {
        // Known palette colors from the generator.
        const palette = <Color>[
          Color(0xFF0EA5E9),
          Color(0xFF8B5CF6),
          Color(0xFFF97316),
          Color(0xFF10B981),
          Color(0xFFEF4444),
          Color(0xFFFBBF24),
          Color(0xFF06B6D4),
          Color(0xFFEC4899),
          Color(0xFF14B8A6),
          Color(0xFF6366F1),
          Color(0xFF84CC16),
          Color(0xFFA78BFA),
          Color(0xFFE91E8C),
          Color(0xFF22C55E),
          Color(0xFFF43F5E),
          Color(0xFF0369A1),
        ];

        for (int i = 0; i < 200; i++) {
          final sigil = SigilGenerator.generate(i);
          expect(
            palette,
            contains(sigil.primaryColor),
            reason: 'primaryColor not in palette for node $i',
          );
          expect(
            palette,
            contains(sigil.secondaryColor),
            reason: 'secondaryColor not in palette for node $i',
          );
          expect(
            palette,
            contains(sigil.tertiaryColor),
            reason: 'tertiaryColor not in palette for node $i',
          );
        }
      });

      test('uses a variety of palette colors across many nodes', () {
        final usedColors = <Color>{};
        for (int i = 0; i < 500; i++) {
          final sigil = SigilGenerator.generate(i);
          usedColors.add(sigil.primaryColor);
          usedColors.add(sigil.secondaryColor);
          usedColors.add(sigil.tertiaryColor);
        }
        // Should use at least 10 of the 16 palette colors.
        expect(
          usedColors.length,
          greaterThanOrEqualTo(10),
          reason:
              'Expected at least 10 palette colors used, '
              'got ${usedColors.length}',
        );
      });
    });

    group('computePoints', () {
      test('returns correct number of outer polygon vertices', () {
        for (int i = 0; i < 50; i++) {
          final sigil = SigilGenerator.generate(i);
          final points = SigilGenerator.computePoints(sigil);

          int expectedPoints = sigil.vertices; // outer polygon
          expectedPoints +=
              sigil.innerRings * sigil.vertices; // inner ring vertices
          if (sigil.centerDot) expectedPoints += 1; // center point

          expect(
            points.length,
            equals(expectedPoints),
            reason:
                'Point count mismatch for node $i: '
                'v=${sigil.vertices}, ir=${sigil.innerRings}, '
                'cd=${sigil.centerDot}',
          );
        }
      });

      test('outer vertices are non-degenerate and finite', () {
        // The sigil generator uses a fast sine/cosine approximation
        // (Bhaskara I) which can deviate significantly from true unit
        // circle values. We only verify that vertices are non-zero,
        // finite, and distinct from each other.
        for (int n = 0; n < 50; n++) {
          final sigil = SigilGenerator.generate(n);
          final points = SigilGenerator.computePoints(sigil);

          for (int i = 0; i < sigil.vertices; i++) {
            final p = points[i];
            final dist = math.sqrt(p.dx * p.dx + p.dy * p.dy);

            expect(
              p.dx.isFinite,
              isTrue,
              reason: 'Outer vertex $i dx is not finite for node $n',
            );
            expect(
              p.dy.isFinite,
              isTrue,
              reason: 'Outer vertex $i dy is not finite for node $n',
            );
            // Vertices should not collapse to the origin.
            expect(
              dist,
              greaterThan(0.01),
              reason: 'Outer vertex $i collapsed to origin for node $n',
            );
          }

          // Outer vertices should not all be the same point.
          if (sigil.vertices >= 2) {
            final allSame = points
                .take(sigil.vertices)
                .every((p) => p == points.first);
            expect(
              allSame,
              isFalse,
              reason: 'All outer vertices are identical for node $n',
            );
          }
        }
      });

      test('inner ring vertices are closer to center than outer vertices', () {
        // Find a sigil with inner rings.
        SigilData? sigil;
        int nodeNum = 0;
        for (int i = 0; i < 200; i++) {
          final s = SigilGenerator.generate(i);
          if (s.innerRings > 0) {
            sigil = s;
            nodeNum = i;
            break;
          }
        }

        if (sigil == null) {
          // Skip if no inner rings found (unlikely but possible).
          return;
        }

        final points = SigilGenerator.computePoints(sigil);

        // Compute average outer vertex distance.
        double outerAvg = 0;
        for (int i = 0; i < sigil.vertices; i++) {
          final p = points[i];
          outerAvg += math.sqrt(p.dx * p.dx + p.dy * p.dy);
        }
        outerAvg /= sigil.vertices;

        // Each inner ring should have smaller average distance than outer.
        for (int ring = 1; ring <= sigil.innerRings; ring++) {
          final ringOffset = ring * sigil.vertices;
          double ringAvg = 0;
          for (int i = 0; i < sigil.vertices; i++) {
            final p = points[ringOffset + i];
            ringAvg += math.sqrt(p.dx * p.dx + p.dy * p.dy);
          }
          ringAvg /= sigil.vertices;

          expect(
            ringAvg,
            lessThan(outerAvg),
            reason:
                'Inner ring $ring avg distance ($ringAvg) is not less than '
                'outer avg distance ($outerAvg) for node $nodeNum',
          );
        }
      });

      test('center dot is at origin when present', () {
        // Find a sigil with centerDot.
        SigilData? sigil;
        for (int i = 0; i < 200; i++) {
          final s = SigilGenerator.generate(i);
          if (s.centerDot) {
            sigil = s;
            break;
          }
        }

        if (sigil == null) return;

        final points = SigilGenerator.computePoints(sigil);
        final lastPoint = points.last;
        expect(lastPoint.dx, closeTo(0.0, 1e-10));
        expect(lastPoint.dy, closeTo(0.0, 1e-10));
      });
    });

    group('computeEdges', () {
      test('outer polygon forms a closed loop', () {
        final sigil = SigilGenerator.generate(42);
        final edges = SigilGenerator.computeEdges(sigil);

        // First N edges should form the outer polygon loop.
        for (int i = 0; i < sigil.vertices; i++) {
          expect(
            edges[i].$1,
            equals(i),
            reason: 'Outer edge $i start vertex mismatch',
          );
          expect(
            edges[i].$2,
            equals((i + 1) % sigil.vertices),
            reason: 'Outer edge $i end vertex mismatch',
          );
        }
      });

      test('edge indices are within valid range', () {
        for (int i = 0; i < 100; i++) {
          final sigil = SigilGenerator.generate(i);
          final points = SigilGenerator.computePoints(sigil);
          final edges = SigilGenerator.computeEdges(sigil);
          final maxIndex = points.length;

          for (int e = 0; e < edges.length; e++) {
            expect(
              edges[e].$1,
              greaterThanOrEqualTo(0),
              reason: 'Edge $e start index negative for node $i',
            );
            expect(
              edges[e].$1,
              lessThan(maxIndex),
              reason:
                  'Edge $e start index out of range for node $i: '
                  '${edges[e].$1} >= $maxIndex',
            );
            expect(
              edges[e].$2,
              greaterThanOrEqualTo(0),
              reason: 'Edge $e end index negative for node $i',
            );
            expect(
              edges[e].$2,
              lessThan(maxIndex),
              reason:
                  'Edge $e end index out of range for node $i: '
                  '${edges[e].$2} >= $maxIndex',
            );
          }
        }
      });

      test('number of edges increases with inner rings', () {
        // Find sigils with different inner ring counts.
        final edgeCountsByRings = <int, int>{};

        for (int i = 0; i < 500; i++) {
          final sigil = SigilGenerator.generate(i);
          final edges = SigilGenerator.computeEdges(sigil);
          // Store the first occurrence for each ring count + same vertices.
          final key = sigil.innerRings;
          if (!edgeCountsByRings.containsKey(key) || sigil.vertices == 5) {
            edgeCountsByRings[key] = edges.length;
          }
        }

        // More inner rings should generally mean more edges.
        if (edgeCountsByRings.containsKey(0) &&
            edgeCountsByRings.containsKey(1)) {
          expect(
            edgeCountsByRings[1]!,
            greaterThan(edgeCountsByRings[0]!),
            reason: '1 inner ring should have more edges than 0',
          );
        }
      });
    });

    group('serialization round-trip', () {
      test('SigilData survives toJson/fromJson', () {
        for (int i = 0; i < 50; i++) {
          final original = SigilGenerator.generate(i);
          final json = original.toJson();
          final restored = SigilData.fromJson(json);

          expect(restored.vertices, equals(original.vertices));
          expect(restored.rotation, equals(original.rotation));
          expect(restored.innerRings, equals(original.innerRings));
          expect(restored.drawRadials, equals(original.drawRadials));
          expect(restored.centerDot, equals(original.centerDot));
          expect(restored.symmetryFold, equals(original.symmetryFold));
          expect(restored.primaryColor, equals(original.primaryColor));
          expect(restored.secondaryColor, equals(original.secondaryColor));
          expect(restored.tertiaryColor, equals(original.tertiaryColor));
        }
      });
    });

    group('edge cases', () {
      test('handles nodeNum 0', () {
        final sigil = SigilGenerator.generate(0);
        expect(sigil.vertices, greaterThanOrEqualTo(3));
        expect(sigil.vertices, lessThanOrEqualTo(8));
      });

      test('handles max 32-bit nodeNum', () {
        final sigil = SigilGenerator.generate(0xFFFFFFFF);
        expect(sigil.vertices, greaterThanOrEqualTo(3));
        expect(sigil.vertices, lessThanOrEqualTo(8));
      });

      test('handles negative nodeNum gracefully', () {
        // Dart ints can be negative; the generator uses bit masking.
        final sigil = SigilGenerator.generate(-1);
        expect(sigil.vertices, greaterThanOrEqualTo(3));
        expect(sigil.vertices, lessThanOrEqualTo(8));
      });

      test('handles very large nodeNum', () {
        final sigil = SigilGenerator.generate(0x7FFFFFFFFFFFFFFF);
        expect(sigil.vertices, greaterThanOrEqualTo(3));
        expect(sigil.vertices, lessThanOrEqualTo(8));
      });
    });
  });
}
