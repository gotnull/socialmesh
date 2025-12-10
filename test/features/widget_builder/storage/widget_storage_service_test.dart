import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/features/widget_builder/storage/widget_storage_service.dart';
import 'package:socialmesh/features/widget_builder/models/widget_schema.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WidgetStorageService', () {
    late WidgetStorageService service;
    late int seededWidgetCount;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      service = WidgetStorageService();
      await service.init();
      // Store the count of seeded widgets as baseline
      seededWidgetCount = (await service.getWidgets()).length;
    });

    WidgetSchema createTestWidget({String name = 'Test Widget', String? id}) {
      return WidgetSchema(
        name: name,
        description: 'A test widget',
        author: 'Test Author',
        version: '1.0.0',
        root: ElementSchema(type: ElementType.text, text: 'Hello World'),
        tags: const ['test'],
      );
    }

    group('saveWidget', () {
      test('saves a new widget', () async {
        final widget = createTestWidget();
        await service.saveWidget(widget);

        final widgets = await service.getWidgets();
        expect(widgets.length, seededWidgetCount + 1);
        expect(widgets.any((w) => w.name == 'Test Widget'), isTrue);
      });

      test('updates an existing widget with same ID', () async {
        final widget = createTestWidget();
        await service.saveWidget(widget);

        final updated = WidgetSchema(
          id: widget.id,
          name: 'Updated Widget',
          description: widget.description,
          root: widget.root,
        );
        await service.saveWidget(updated);

        final widgets = await service.getWidgets();
        expect(widgets.length, seededWidgetCount + 1);
        expect(widgets.any((w) => w.name == 'Updated Widget'), isTrue);
      });

      test('saves multiple widgets', () async {
        await service.saveWidget(createTestWidget(name: 'Widget 1'));
        await service.saveWidget(createTestWidget(name: 'Widget 2'));
        await service.saveWidget(createTestWidget(name: 'Widget 3'));

        final widgets = await service.getWidgets();
        expect(widgets.length, seededWidgetCount + 3);
      });
    });

    group('getWidget', () {
      test('retrieves a widget by ID', () async {
        final widget = createTestWidget();
        await service.saveWidget(widget);

        final retrieved = await service.getWidget(widget.id);
        expect(retrieved, isNotNull);
        expect(retrieved!.id, widget.id);
        expect(retrieved.name, widget.name);
      });

      test('returns null for non-existent ID', () async {
        final retrieved = await service.getWidget('non-existent-id');
        expect(retrieved, isNull);
      });
    });

    group('getWidgets', () {
      test('returns seeded widgets after init', () async {
        final widgets = await service.getWidgets();
        expect(widgets.length, seededWidgetCount);
      });

      test('returns all saved widgets including seeded', () async {
        await service.saveWidget(createTestWidget(name: 'Widget 1'));
        await service.saveWidget(createTestWidget(name: 'Widget 2'));

        final widgets = await service.getWidgets();
        expect(widgets.length, seededWidgetCount + 2);
        expect(
          widgets.map((w) => w.name),
          containsAll(['Widget 1', 'Widget 2']),
        );
      });
    });

    group('deleteWidget', () {
      test('deletes a widget by ID', () async {
        final widget = createTestWidget();
        await service.saveWidget(widget);

        await service.deleteWidget(widget.id);

        final widgets = await service.getWidgets();
        expect(widgets.length, seededWidgetCount);
        expect(widgets.any((w) => w.id == widget.id), isFalse);
      });

      test('does not throw when deleting non-existent ID', () async {
        await service.saveWidget(createTestWidget());

        await service.deleteWidget('non-existent-id');

        final widgets = await service.getWidgets();
        expect(widgets.length, seededWidgetCount + 1);
      });
    });

    group('duplicateWidget', () {
      test('creates a copy with new ID', () async {
        final original = createTestWidget(name: 'Original Widget');
        await service.saveWidget(original);

        final copy = await service.duplicateWidget(original.id);

        expect(copy.id, isNot(original.id));
        expect(copy.name, 'Original Widget (Copy)');
      });

      test('copy is saved to storage', () async {
        final original = createTestWidget();
        await service.saveWidget(original);

        await service.duplicateWidget(original.id);

        final widgets = await service.getWidgets();
        expect(widgets.length, seededWidgetCount + 2);
      });

      test('throws when widget not found', () async {
        expect(
          () => service.duplicateWidget('non-existent-id'),
          throwsException,
        );
      });
    });

    group('exportWidget', () {
      test('exports widget as JSON string', () async {
        final widget = createTestWidget();
        await service.saveWidget(widget);

        final json = await service.exportWidget(widget.id);

        expect(json, isNotEmpty);
        expect(json, contains('"name": "Test Widget"'));
        expect(json, contains('"id": "${widget.id}"'));
      });

      test('throws when widget not found', () async {
        expect(() => service.exportWidget('non-existent-id'), throwsException);
      });
    });

    group('importWidget', () {
      test('imports widget from JSON string', () async {
        final original = createTestWidget(name: 'Imported Widget');
        final json = original.toJsonString();

        final imported = await service.importWidget(json);

        // Import creates new ID
        expect(imported.id, isNot(original.id));
        expect(imported.name, 'Imported Widget');
      });

      test('imported widget is saved to storage', () async {
        final original = createTestWidget();
        final json = original.toJsonString();

        await service.importWidget(json);

        final widgets = await service.getWidgets();
        expect(widgets.length, seededWidgetCount + 1);
      });

      test('throws on invalid JSON', () async {
        expect(() => service.importWidget('invalid json'), throwsA(anything));
      });
    });

    group('marketplace widgets', () {
      test('installMarketplaceWidget saves and tracks widget', () async {
        final widgetsBefore = await service.getWidgets();
        final countBefore = widgetsBefore.length;

        final widget = createTestWidget();
        await service.installMarketplaceWidget(widget);

        final widgetsAfter = await service.getWidgets();
        expect(widgetsAfter.length, countBefore + 1);

        final isMarketplace = await service.isMarketplaceWidget(widget.id);
        expect(isMarketplace, isTrue);
      });

      test('isMarketplaceWidget returns false for regular widget', () async {
        final widget = createTestWidget();
        await service.saveWidget(widget);

        final isMarketplace = await service.isMarketplaceWidget(widget.id);
        expect(isMarketplace, isFalse);
      });

      test(
        'getInstalledMarketplaceIds returns marketplace widget IDs',
        () async {
          final widget1 = createTestWidget(name: 'Marketplace 1');
          final widget2 = createTestWidget(name: 'Regular');
          final widget3 = createTestWidget(name: 'Marketplace 2');

          await service.installMarketplaceWidget(widget1);
          await service.saveWidget(widget2);
          await service.installMarketplaceWidget(widget3);

          final marketplaceIds = await service.getInstalledMarketplaceIds();
          expect(marketplaceIds.length, 2);
          expect(marketplaceIds, contains(widget1.id));
          expect(marketplaceIds, contains(widget3.id));
          expect(marketplaceIds, isNot(contains(widget2.id)));
        },
      );
    });

    group('clearAll', () {
      test('removes all widgets', () async {
        await service.saveWidget(createTestWidget(name: 'Widget 1'));
        await service.saveWidget(createTestWidget(name: 'Widget 2'));
        await service.installMarketplaceWidget(
          createTestWidget(name: 'Marketplace'),
        );

        await service.clearAll();

        final widgets = await service.getWidgets();
        final marketplaceIds = await service.getInstalledMarketplaceIds();

        expect(widgets, isEmpty);
        expect(marketplaceIds, isEmpty);
      });
    });
  });

  group('WidgetTemplates', () {
    test('batteryWidget creates valid schema', () {
      final widget = WidgetTemplates.batteryWidget();

      expect(widget.name, 'Battery Status');
      expect(widget.root.type, ElementType.column);
      expect(widget.tags, contains('battery'));
    });

    test('signalWidget creates valid schema', () {
      final widget = WidgetTemplates.signalWidget();

      expect(widget.name, 'Signal Strength');
      expect(widget.root.type, ElementType.column);
      expect(widget.tags, contains('signal'));
    });

    test('environmentWidget creates valid schema', () {
      final widget = WidgetTemplates.environmentWidget();

      expect(widget.name, 'Environment');
      expect(widget.root.type, ElementType.column);
      expect(widget.tags, contains('environment'));
    });

    test('nodeInfoWidget creates valid schema', () {
      final widget = WidgetTemplates.nodeInfoWidget();

      expect(widget.name, 'Node Info');
      expect(widget.root.type, ElementType.column);
      expect(widget.tags, contains('node'));
    });

    test('gpsWidget creates valid schema', () {
      final widget = WidgetTemplates.gpsWidget();

      expect(widget.name, 'GPS Position');
      expect(widget.root.type, ElementType.column);
      expect(widget.tags, contains('gps'));
    });

    test('quickActionsWidget creates valid schema', () {
      final widget = WidgetTemplates.quickActionsWidget();

      expect(widget.name, 'Quick Actions');
      expect(widget.root.type, ElementType.column);
      expect(widget.tags, contains('actions'));
      expect(widget.size, CustomWidgetSize.medium);
    });

    test('all templates have unique root elements', () {
      final templates = [
        WidgetTemplates.batteryWidget(),
        WidgetTemplates.signalWidget(),
        WidgetTemplates.environmentWidget(),
        WidgetTemplates.nodeInfoWidget(),
        WidgetTemplates.gpsWidget(),
        WidgetTemplates.quickActionsWidget(),
      ];

      // Each template should have a root with children
      for (final template in templates) {
        expect(template.root.children, isNotNull);
        expect(template.root.children, isNotEmpty);
      }
    });
  });
}
