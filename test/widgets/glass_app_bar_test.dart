// Glass App Bar Widget Tests
//
// Tests the glassmorphic app bar components to verify:
// - BackdropFilter is present for blur effect
// - Background is transparent (no Material tinting)
// - App bar is pinned while scrolling
// - iOS bounce physics are applied via kGlassScrollPhysics

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/widgets/glass_app_bar.dart';
import 'package:socialmesh/core/widgets/glass_scaffold.dart';

void main() {
  group('GlassAppBar', () {
    testWidgets('renders with BackdropFilter for blur effect', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            extendBodyBehindAppBar: true,
            appBar: GlassAppBar(title: Text('Test Title')),
            body: SizedBox.expand(),
          ),
        ),
      );

      // Verify BackdropFilter exists for blur
      expect(find.byType(BackdropFilter), findsOneWidget);

      // Verify ClipRect exists to bound the blur (may be more than one in widget tree)
      expect(find.byType(ClipRect), findsWidgets);

      // Verify title is displayed
      expect(find.text('Test Title'), findsOneWidget);
    });

    testWidgets('has transparent background color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            extendBodyBehindAppBar: true,
            appBar: GlassAppBar(title: Text('Test')),
            body: SizedBox.expand(),
          ),
        ),
      );

      // Find the AppBar widget
      final appBar = tester.widget<AppBar>(find.byType(AppBar));

      // Verify background is transparent
      expect(appBar.backgroundColor, equals(Colors.transparent));
      expect(appBar.surfaceTintColor, equals(Colors.transparent));
      expect(appBar.scrolledUnderElevation, equals(0));
      expect(appBar.elevation, equals(0));
    });

    testWidgets('displays actions and leading widgets', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            extendBodyBehindAppBar: true,
            appBar: GlassAppBar(
              title: const Text('Test'),
              leading: const Icon(Icons.menu),
              actions: const [Icon(Icons.settings), Icon(Icons.search)],
            ),
            body: const SizedBox.expand(),
          ),
        ),
      );

      expect(find.byIcon(Icons.menu), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });
  });

  group('GlassSliverAppBar', () {
    testWidgets('renders with BackdropFilter in CustomScrollView', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            extendBodyBehindAppBar: true,
            body: CustomScrollView(
              slivers: const [
                GlassSliverAppBar(title: Text('Sliver Test'), pinned: true),
                SliverToBoxAdapter(child: SizedBox(height: 2000)),
              ],
            ),
          ),
        ),
      );

      // Verify BackdropFilter exists
      expect(find.byType(BackdropFilter), findsOneWidget);

      // Verify title is displayed
      expect(find.text('Sliver Test'), findsOneWidget);
    });

    testWidgets('remains visible when scrolling (pinned)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            extendBodyBehindAppBar: true,
            body: CustomScrollView(
              slivers: [
                const GlassSliverAppBar(
                  title: Text('Pinned Title'),
                  pinned: true,
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Container(
                      height: 100,
                      color: index.isEven ? Colors.blue : Colors.red,
                      child: Center(child: Text('Item $index')),
                    ),
                    childCount: 50,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Initially visible
      expect(find.text('Pinned Title'), findsOneWidget);

      // Scroll down significantly
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();

      // Title should still be visible because pinned: true
      expect(find.text('Pinned Title'), findsOneWidget);

      // BackdropFilter should still be present
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('has transparent Material styling', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            extendBodyBehindAppBar: true,
            body: CustomScrollView(
              slivers: const [
                GlassSliverAppBar(title: Text('Test'), pinned: true),
                SliverToBoxAdapter(child: SizedBox(height: 500)),
              ],
            ),
          ),
        ),
      );

      // Find the SliverAppBar widget
      final sliverAppBar = tester.widget<SliverAppBar>(
        find.byType(SliverAppBar),
      );

      // Verify background is transparent
      expect(sliverAppBar.backgroundColor, equals(Colors.transparent));
      expect(sliverAppBar.surfaceTintColor, equals(Colors.transparent));
      expect(sliverAppBar.scrolledUnderElevation, equals(0));
      expect(sliverAppBar.elevation, equals(0));
    });
  });

  group('GlassScaffold', () {
    testWidgets('wraps content with glass app bar and proper structure', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: GlassScaffold(
            title: 'Glass Scaffold Test',
            slivers: [
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => ListTile(title: Text('Item $index')),
                  childCount: 20,
                ),
              ),
            ],
          ),
        ),
      );

      // Verify title is displayed
      expect(find.text('Glass Scaffold Test'), findsOneWidget);

      // Verify BackdropFilter exists
      expect(find.byType(BackdropFilter), findsOneWidget);

      // Verify CustomScrollView is used
      expect(find.byType(CustomScrollView), findsOneWidget);

      // Verify content is rendered
      expect(find.text('Item 0'), findsOneWidget);
    });

    testWidgets('extendBodyBehindAppBar is enabled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: GlassScaffold(
            title: 'Test',
            slivers: const [SliverToBoxAdapter(child: SizedBox(height: 100))],
          ),
        ),
      );

      // Find the Scaffold
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));

      // Verify extendBodyBehindAppBar is true
      expect(scaffold.extendBodyBehindAppBar, isTrue);
    });

    testWidgets('GlassScaffold.body wraps content correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const GlassScaffold.body(
            title: 'Body Test',
            body: Center(child: Text('Body Content')),
          ),
        ),
      );

      // Verify title is displayed
      expect(find.text('Body Test'), findsOneWidget);

      // Verify body content is displayed
      expect(find.text('Body Content'), findsOneWidget);

      // Verify BackdropFilter exists
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('supports actions in app bar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: GlassScaffold(
            title: 'Test',
            actions: const [Icon(Icons.add), Icon(Icons.settings)],
            slivers: const [SliverToBoxAdapter(child: SizedBox(height: 100))],
          ),
        ),
      );

      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });
  });

  group('GlassConstants', () {
    test('provides appropriate blur sigma values', () {
      // iOS value should be higher
      expect(GlassConstants.blurSigmaIOS, equals(20.0));

      // Android value should be lower for performance
      expect(GlassConstants.blurSigmaAndroid, equals(14.0));
      expect(
        GlassConstants.blurSigmaAndroid,
        lessThan(GlassConstants.blurSigmaIOS),
      );
    });

    test('provides opacity constants within valid range', () {
      expect(GlassConstants.fillOpacity, greaterThan(0));
      expect(GlassConstants.fillOpacity, lessThan(1));
      expect(GlassConstants.borderOpacity, greaterThan(0));
      expect(GlassConstants.borderOpacity, lessThan(1));
    });
  });

  group('kGlassScrollPhysics', () {
    test(
      'is AlwaysScrollableScrollPhysics with BouncingScrollPhysics parent',
      () {
        // Verify kGlassScrollPhysics is an AlwaysScrollableScrollPhysics
        expect(kGlassScrollPhysics, isA<AlwaysScrollableScrollPhysics>());

        // Verify its parent is BouncingScrollPhysics
        final parent = kGlassScrollPhysics.parent;
        expect(parent, isA<BouncingScrollPhysics>());
      },
    );

    testWidgets('GlassScaffold uses kGlassScrollPhysics by default', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: GlassScaffold(
            title: 'Bounce Test',
            slivers: const [SliverToBoxAdapter(child: SizedBox(height: 100))],
          ),
        ),
      );

      // Find the CustomScrollView inside GlassScaffold
      final scrollViewFinder = find.byType(CustomScrollView);
      expect(scrollViewFinder, findsOneWidget);

      // Verify it has the expected physics type
      final scrollView = tester.widget<CustomScrollView>(scrollViewFinder);
      expect(scrollView.physics, isA<AlwaysScrollableScrollPhysics>());
      expect(scrollView.physics?.parent, isA<BouncingScrollPhysics>());
    });

    testWidgets('GlassScaffold allows physics override', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: GlassScaffold(
            title: 'Custom Physics',
            physics: const NeverScrollableScrollPhysics(),
            slivers: const [SliverToBoxAdapter(child: SizedBox(height: 100))],
          ),
        ),
      );

      // Find the CustomScrollView
      final scrollView = tester.widget<CustomScrollView>(
        find.byType(CustomScrollView),
      );

      // Verify physics was overridden
      expect(scrollView.physics, isA<NeverScrollableScrollPhysics>());
    });

    testWidgets('content is scrollable even when it does not overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: GlassScaffold(
            title: 'Small Content',
            slivers: const [
              SliverToBoxAdapter(child: SizedBox(height: 50)), // Small content
            ],
          ),
        ),
      );

      // Find the CustomScrollView
      final scrollViewFinder = find.byType(CustomScrollView);
      expect(scrollViewFinder, findsOneWidget);

      // Attempt to scroll - with AlwaysScrollableScrollPhysics this should work
      // and return to position (bounce back)
      await tester.drag(scrollViewFinder, const Offset(0, -100));
      await tester.pump();

      // The scroll should have been attempted (no assertion errors)
      // With BouncingScrollPhysics, it will bounce back
      await tester.pumpAndSettle();
    });
  });
}
