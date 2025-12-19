import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:logger/logger.dart';
import 'package:socialmesh/features/widget_builder/marketplace/widget_marketplace_service.dart';
import 'package:socialmesh/features/widget_builder/models/widget_schema.dart';

/// Silent logger for tests - suppresses all output
Logger _silentLogger() => Logger(level: Level.off);

void main() {
  group('WidgetMarketplaceService', () {
    late WidgetMarketplaceService service;

    group('browse', () {
      test('returns widgets on successful response', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, contains('/widgetsBrowse'));
          return http.Response(
            jsonEncode({
              'widgets': [
                {
                  'id': 'widget-1',
                  'name': 'Test Widget',
                  'description': 'A test widget',
                  'author': 'TestAuthor',
                  'authorId': 'user-1',
                  'version': '1.0.0',
                  'downloads': 100,
                  'rating': 4.5,
                  'ratingCount': 10,
                  'tags': ['test'],
                  'category': 'general',
                  'createdAt': '2024-01-01T00:00:00Z',
                  'updatedAt': '2024-01-15T00:00:00Z',
                },
              ],
              'total': 1,
              'page': 1,
              'hasMore': false,
            }),
            200,
          );
        });

        service = WidgetMarketplaceService(
          baseUrl: 'http://test.com/widgets',
          client: mockClient,
          logger: _silentLogger(),
        );

        final response = await service.browse();

        expect(response.widgets.length, 1);
        expect(response.widgets.first.name, 'Test Widget');
        expect(response.total, 1);
        expect(response.hasMore, false);
      });

      test('includes query parameters', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.queryParameters['page'], '2');
          expect(request.url.queryParameters['limit'], '10');
          expect(request.url.queryParameters['category'], 'sensors');
          expect(request.url.queryParameters['sort'], 'popular');
          expect(request.url.queryParameters['q'], 'battery');

          return http.Response(
            jsonEncode({
              'widgets': [],
              'total': 0,
              'page': 2,
              'hasMore': false,
            }),
            200,
          );
        });

        service = WidgetMarketplaceService(
          baseUrl: 'http://test.com/widgets',
          client: mockClient,
          logger: _silentLogger(),
        );

        await service.browse(
          page: 2,
          limit: 10,
          category: 'sensors',
          sortBy: 'popular',
          search: 'battery',
        );
      });

      test('throws on network error', () async {
        final mockClient = MockClient((request) async {
          throw Exception('Network error');
        });

        service = WidgetMarketplaceService(
          baseUrl: 'http://test.com/widgets',
          client: mockClient,
          logger: _silentLogger(),
        );

        expect(() => service.browse(), throwsA(isA<MarketplaceException>()));
      });
    });

    group('getFeatured', () {
      test('returns featured widgets on success', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, contains('/widgetsFeatured'));
          return http.Response(
            jsonEncode([
              {
                'id': 'featured-1',
                'name': 'Featured Widget',
                'description': 'A featured widget',
                'author': 'FeaturedAuthor',
                'authorId': 'user-1',
                'version': '2.0.0',
                'downloads': 500,
                'rating': 4.8,
                'ratingCount': 100,
                'tags': ['featured', 'popular'],
                'category': 'status',
                'createdAt': '2024-01-01T00:00:00Z',
                'updatedAt': '2024-01-15T00:00:00Z',
              },
            ]),
            200,
          );
        });

        service = WidgetMarketplaceService(
          baseUrl: 'http://test.com/widgets',
          client: mockClient,
          logger: _silentLogger(),
        );

        final featured = await service.getFeatured();

        expect(featured.length, 1);
        expect(featured.first.name, 'Featured Widget');
        expect(featured.first.rating, 4.8);
      });

      test('throws on network error', () async {
        final mockClient = MockClient((request) async {
          throw Exception('Network error');
        });

        service = WidgetMarketplaceService(
          baseUrl: 'http://test.com/widgets',
          client: mockClient,
          logger: _silentLogger(),
        );

        expect(
          () => service.getFeatured(),
          throwsA(isA<MarketplaceException>()),
        );
      });
    });

    group('getWidget', () {
      test('returns widget details on success', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, contains('/widgetsGet/widget-123'));
          return http.Response(
            jsonEncode({
              'id': 'widget-123',
              'name': 'Detailed Widget',
              'description': 'Full widget details',
              'author': 'DetailAuthor',
              'authorId': 'user-1',
              'version': '1.5.0',
              'downloads': 250,
              'rating': 4.2,
              'ratingCount': 25,
              'tags': ['detail'],
              'category': 'sensors',
              'createdAt': '2024-01-01T00:00:00Z',
              'updatedAt': '2024-01-15T00:00:00Z',
            }),
            200,
          );
        });

        service = WidgetMarketplaceService(
          baseUrl: 'http://test.com/widgets',
          client: mockClient,
          logger: _silentLogger(),
        );

        final widget = await service.getWidget('widget-123');

        expect(widget.id, 'widget-123');
        expect(widget.name, 'Detailed Widget');
      });

      test('throws on 404', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Not found', 404);
        });

        service = WidgetMarketplaceService(
          baseUrl: 'http://test.com/widgets',
          client: mockClient,
          logger: _silentLogger(),
        );

        expect(
          () => service.getWidget('non-existent'),
          throwsA(isA<MarketplaceException>()),
        );
      });
    });

    group('downloadWidget', () {
      test('returns widget schema on success', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, contains('/widgetsDownload'));
          expect(request.url.queryParameters['id'], 'widget-123');
          return http.Response(
            jsonEncode({
              'id': 'widget-123',
              'name': 'Downloaded Widget',
              'description': 'Widget schema for download',
              'version': '1.0.0',
              'root': {'type': 'text', 'text': 'Hello World'},
            }),
            200,
          );
        });

        service = WidgetMarketplaceService(
          baseUrl: 'http://test.com/widgets',
          client: mockClient,
          logger: _silentLogger(),
        );

        final schema = await service.downloadWidget('widget-123');

        expect(schema.name, 'Downloaded Widget');
        expect(schema.root.type, ElementType.text);
      });

      test('throws on network error for any ID', () async {
        final mockClient = MockClient((request) async {
          throw Exception('Network error');
        });

        service = WidgetMarketplaceService(
          baseUrl: 'http://test.com/widgets',
          client: mockClient,
          logger: _silentLogger(),
        );

        // Should throw exception on any ID when network fails
        expect(
          () => service.downloadWidget('battery-gauge-pro'),
          throwsA(isA<MarketplaceException>()),
        );
      });

      test('throws on any ID when network fails', () async {
        final mockClient = MockClient((request) async {
          throw Exception('Network error');
        });

        service = WidgetMarketplaceService(
          baseUrl: 'http://test.com/widgets',
          client: mockClient,
          logger: _silentLogger(),
        );

        expect(
          () => service.downloadWidget('unknown-widget-id'),
          throwsA(isA<MarketplaceException>()),
        );
      });
    });
  });

  group('MarketplaceResponse', () {
    test('fromJson parses correctly', () {
      final json = {
        'widgets': [
          {
            'id': 'w1',
            'name': 'Widget 1',
            'description': 'Description 1',
            'author': 'Author',
            'authorId': 'a1',
            'version': '1.0.0',
            'downloads': 50,
            'rating': 4.0,
            'ratingCount': 5,
            'tags': ['tag1'],
            'category': 'general',
            'createdAt': '2024-01-01T00:00:00Z',
            'updatedAt': '2024-01-01T00:00:00Z',
          },
        ],
        'total': 100,
        'page': 3,
        'hasMore': true,
      };

      final response = MarketplaceResponse.fromJson(json);

      expect(response.widgets.length, 1);
      expect(response.total, 100);
      expect(response.page, 3);
      expect(response.hasMore, true);
    });

    test('hasMore defaults to false when missing', () {
      final json = {'widgets': [], 'total': 0, 'page': 1};

      final response = MarketplaceResponse.fromJson(json);

      expect(response.hasMore, false);
    });
  });

  group('MarketplaceWidget', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 'test-id',
        'name': 'Test Widget',
        'description': 'A test description',
        'author': 'TestAuthor',
        'authorId': 'user-123',
        'version': '2.1.0',
        'thumbnailUrl': 'https://example.com/thumb.png',
        'installs': 1234,
        'rating': 4.75,
        'ratingCount': 89,
        'tags': ['one', 'two', 'three'],
        'category': 'sensors',
        'createdAt': '2024-03-15T10:30:00Z',
        'updatedAt': '2024-03-20T14:45:00Z',
      };

      final widget = MarketplaceWidget.fromJson(json);

      expect(widget.id, 'test-id');
      expect(widget.name, 'Test Widget');
      expect(widget.description, 'A test description');
      expect(widget.author, 'TestAuthor');
      expect(widget.authorId, 'user-123');
      expect(widget.thumbnailUrl, 'https://example.com/thumb.png');
      expect(widget.installs, 1234);
      expect(widget.rating, 4.75);
      expect(widget.ratingCount, 89);
      expect(widget.tags, ['one', 'two', 'three']);
      expect(widget.category, 'sensors');
      expect(widget.createdAt.year, 2024);
      expect(widget.updatedAt.month, 3);
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'id': 'minimal-id',
        'name': 'Minimal Widget',
        'author': 'Author',
        'authorId': 'user-1',
      };

      final widget = MarketplaceWidget.fromJson(json);

      expect(widget.id, 'minimal-id');
      expect(widget.description, '');
      expect(widget.thumbnailUrl, isNull);
      expect(widget.installs, 0);
      expect(widget.rating, 0.0);
      expect(widget.ratingCount, 0);
      expect(widget.tags, isEmpty);
      expect(widget.category, 'general');
    });
  });

  group('MarketplaceException', () {
    test('toString includes message', () {
      final exception = MarketplaceException('Something went wrong');
      expect(
        exception.toString(),
        'MarketplaceException: Something went wrong',
      );
    });

    test('message is accessible', () {
      final exception = MarketplaceException('Error message');
      expect(exception.message, 'Error message');
    });
  });

  group('WidgetCategories', () {
    test('all categories are defined', () {
      expect(WidgetCategories.all, contains(WidgetCategories.deviceStatus));
      expect(WidgetCategories.all, contains(WidgetCategories.metrics));
      expect(WidgetCategories.all, contains(WidgetCategories.charts));
      expect(WidgetCategories.all, contains(WidgetCategories.mesh));
      expect(WidgetCategories.all, contains(WidgetCategories.location));
      expect(WidgetCategories.all, contains(WidgetCategories.weather));
      expect(WidgetCategories.all, contains(WidgetCategories.utility));
      expect(WidgetCategories.all, contains(WidgetCategories.other));
    });

    test('getDisplayName returns human readable names', () {
      expect(WidgetCategories.getDisplayName('device-status'), 'Device Status');
      expect(WidgetCategories.getDisplayName('metrics'), 'Metrics');
      expect(WidgetCategories.getDisplayName('charts'), 'Charts');
      expect(WidgetCategories.getDisplayName('mesh'), 'Mesh Network');
      expect(WidgetCategories.getDisplayName('location'), 'Location');
      expect(WidgetCategories.getDisplayName('weather'), 'Weather');
      expect(WidgetCategories.getDisplayName('utility'), 'Utility');
      expect(WidgetCategories.getDisplayName('other'), 'Other');
    });

    test('getDisplayName returns input for unknown category', () {
      expect(WidgetCategories.getDisplayName('unknown'), 'unknown');
    });
  });
}
