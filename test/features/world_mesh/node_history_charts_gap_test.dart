// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Issue #197 - node history charts must place each snapshot at its actual
// timestamp. Pins that the rendered LineChart carries epoch-ms spot x
// values and a time-proportional domain, so a 1-hour gap is 12x wider
// than a 5-minute one instead of both getting one equal slot.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/world_mesh/services/node_history_service.dart';
import 'package:socialmesh/features/world_mesh/widgets/node_history_charts.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/models/presence_confidence.dart';

NodeHistoryEntry _entry(DateTime timestamp, int battery) {
  return NodeHistoryEntry(
    timestamp: timestamp,
    batteryLevel: battery,
    presenceConfidence: PresenceConfidence.active,
    neighborCount: 0,
    gatewayCount: 0,
  );
}

void main() {
  testWidgets('spots sit at epoch-ms timestamps, gaps stay proportional', (
    tester,
  ) async {
    final t0 = DateTime(2026, 6, 10, 12, 0);
    final t1 = t0.add(const Duration(minutes: 5));
    final t2 = t0.add(const Duration(minutes: 65));
    final history = [_entry(t0, 80), _entry(t1, 75), _entry(t2, 70)];

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: NodeHistoryCharts(
              history: history,
              accentColor: Colors.blue,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    final spots = chart.data.lineBarsData.single.spots;

    expect(spots, hasLength(3));
    expect(spots[0].x, t0.millisecondsSinceEpoch.toDouble());
    expect(spots[1].x, t1.millisecondsSinceEpoch.toDouble());
    expect(spots[2].x, t2.millisecondsSinceEpoch.toDouble());

    // The 60-minute gap is 12x the 5-minute gap.
    expect((spots[2].x - spots[1].x) / (spots[1].x - spots[0].x), 12.0);

    // Domain spans exactly the sampled window (65 minutes).
    expect(chart.data.minX, spots.first.x);
    expect(chart.data.maxX, spots.last.x);
    expect(
      chart.data.maxX - chart.data.minX,
      const Duration(minutes: 65).inMilliseconds.toDouble(),
    );
  });
}
