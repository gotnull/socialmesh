// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/widgets/chart_legend_header.dart';

void main() {
  const entries = [
    ChartLegendEntry(color: Colors.green, label: 'Battery'),
    ChartLegendEntry(color: Colors.yellow, label: 'Voltage'),
    ChartLegendEntry(color: Colors.blue, label: 'Channel Util'),
    ChartLegendEntry(color: Colors.pink, label: 'Air Util TX'),
  ];

  Future<ChartLegendHeaderDelegate> pumpAndMeasure(
    WidgetTester tester, {
    required double width,
    double textScale = 1.0,
  }) async {
    late ChartLegendHeaderDelegate delegate;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 800),
            textScaler: TextScaler.linear(textScale),
          ),
          child: Builder(
            builder: (context) {
              delegate = ChartLegendHeaderDelegate.measure(
                context: context,
                entries: entries,
                trailingText: '128 readings',
              );
              return CustomScrollView(
                slivers: [
                  SliverPersistentHeader(pinned: true, delegate: delegate),
                  const SliverToBoxAdapter(child: SizedBox(height: 1200)),
                ],
              );
            },
          ),
        ),
      ),
    );
    return delegate;
  }

  group('ChartLegendHeaderDelegate.measure', () {
    testWidgets('single-run legend keeps the 40px baseline extent', (
      tester,
    ) async {
      final delegate = await pumpAndMeasure(tester, width: 800);
      expect(delegate.extent, 40.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('narrow width grows the extent for wrapped runs', (
      tester,
    ) async {
      final delegate = await pumpAndMeasure(tester, width: 320);
      expect(
        delegate.extent,
        greaterThan(40.0),
        reason:
            'Four labels cannot fit one run at 320px; the header must '
            'grow instead of clipping the second run.',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('large text scale grows the extent', (tester) async {
      final normal = await pumpAndMeasure(tester, width: 400);
      final scaled = await pumpAndMeasure(tester, width: 400, textScale: 2.0);
      expect(scaled.extent, greaterThan(normal.extent));
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders without overflow at accessibility scale', (
      tester,
    ) async {
      await pumpAndMeasure(tester, width: 320, textScale: 2.0);
      expect(tester.takeException(), isNull);
    });
  });
}
