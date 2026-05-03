// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/theme.dart';
import 'package:socialmesh/core/widgets/settings_primitives.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(body: child),
  );
}

void main() {
  group('SettingsSectionHeader', () {
    testWidgets('renders the title text verbatim (no uppercasing)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const SettingsSectionHeader(title: 'Server Section')),
      );
      // The canonical inner-settings header preserves case as supplied;
      // it is not the same as SectionTitle, which uppercases its label.
      // ARB callers pass already-cased copy, so don't double-transform.
      expect(find.text('Server Section'), findsOneWidget);
    });

    testWidgets('applies the canonical 12px bold letterSpaced style', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const SettingsSectionHeader(title: 'A')));

      final text = tester.widget<Text>(find.text('A'));
      expect(text.style?.fontSize, 12);
      expect(text.style?.fontWeight, FontWeight.bold);
      expect(text.style?.letterSpacing, 1.2);
    });

    testWidgets('uses the canonical fromLTRB(16, 8, 16, 8) padding', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const SettingsSectionHeader(title: 'A')));

      final padding = tester.widget<Padding>(find.byType(Padding));
      expect(
        padding.padding,
        const EdgeInsets.fromLTRB(AppTheme.spacing16, 8, 16, 8),
      );
    });
  });

  group('SettingsTile', () {
    testWidgets('renders icon, title, subtitle, and trailing', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SettingsTile(
            icon: Icons.cloud,
            title: 'Enable',
            subtitle: 'Turn it on',
            trailing: Icon(Icons.chevron_right),
          ),
        ),
      );

      expect(find.byIcon(Icons.cloud), findsOneWidget);
      expect(find.text('Enable'), findsOneWidget);
      expect(find.text('Turn it on'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('renders without a trailing widget', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SettingsTile(
            icon: Icons.cloud,
            title: 'Enable',
            subtitle: 'Turn it on',
          ),
        ),
      );

      // Sanity: no chevron / no other trailing icon present.
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      // The leading icon is still rendered.
      expect(find.byIcon(Icons.cloud), findsOneWidget);
    });

    testWidgets('renders without a subtitle when omitted', (tester) async {
      await tester.pumpWidget(
        _wrap(const SettingsTile(icon: Icons.cloud, title: 'Title only')),
      );

      expect(find.text('Title only'), findsOneWidget);
      // No second-line text widget.
      expect(find.text('Turn it on'), findsNothing);
    });

    testWidgets('fires onTap when supplied (action-tile shape)', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          SettingsTile(
            icon: Icons.bolt,
            title: 'Action',
            subtitle: 'tap me',
            onTap: () => taps++,
          ),
        ),
      );

      await tester.tap(find.text('Action'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('omits InkWell wrapper when onTap is null (passive shape)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const SettingsTile(
            icon: Icons.cloud,
            title: 'Toggle',
            subtitle: 'managed by trailing widget',
          ),
        ),
      );

      // No InkWell — the surrounding ThemedSwitch / trailing widget owns
      // its own gesture detector. This matches the canonical MQTT toggle
      // tile shape.
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('uses the iconColor override when supplied', (tester) async {
      const accent = Color(0xFF00FF00);
      await tester.pumpWidget(
        _wrap(
          const SettingsTile(
            icon: Icons.bolt,
            iconColor: accent,
            title: 'Active',
            subtitle: 'Highlighted',
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.bolt));
      expect(icon.color, accent);
    });

    testWidgets(
      'title uses fontSize 15 / w500 — the canonical inner-settings tile shape',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const SettingsTile(
              icon: Icons.cloud,
              title: 'Enable',
              subtitle: 'Turn it on',
            ),
          ),
        );

        final title = tester.widget<Text>(find.text('Enable'));
        expect(title.style?.fontSize, 15);
        expect(title.style?.fontWeight, FontWeight.w500);
      },
    );

    testWidgets('wraps content in a card-coloured Container with radius12', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const SettingsTile(
            icon: Icons.cloud,
            title: 'Enable',
            subtitle: 'Turn it on',
          ),
        ),
      );

      final container = tester.widget<Container>(
        find
            .ancestor(
              of: find.byIcon(Icons.cloud),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(container.margin, isNotNull);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(AppTheme.radius12));
    });
  });

  group('FieldGroupCard', () {
    testWidgets('renders its child', (tester) async {
      await tester.pumpWidget(
        _wrap(const FieldGroupCard(child: Text('Inside'))),
      );
      expect(find.text('Inside'), findsOneWidget);
    });

    testWidgets(
      'uses the canonical default margin/padding (16h/2v + spacing16)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(const FieldGroupCard(child: SizedBox.shrink())),
        );

        final container = tester.widget<Container>(
          find
              .ancestor(
                of: find.byType(SizedBox),
                matching: find.byType(Container),
              )
              .first,
        );
        expect(
          container.margin,
          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        );
        expect(container.padding, const EdgeInsets.all(AppTheme.spacing16));
      },
    );

    testWidgets('honours an overridden margin (callers can pass vertical: 8)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const FieldGroupCard(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox.shrink(),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find
            .ancestor(
              of: find.byType(SizedBox),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        container.margin,
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      );
    });

    testWidgets('decoration uses card colour and radius12', (tester) async {
      await tester.pumpWidget(
        _wrap(const FieldGroupCard(child: SizedBox.shrink())),
      );

      final container = tester.widget<Container>(
        find
            .ancestor(
              of: find.byType(SizedBox),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(AppTheme.radius12));
      expect(decoration.color, isNotNull);
    });
  });
}
