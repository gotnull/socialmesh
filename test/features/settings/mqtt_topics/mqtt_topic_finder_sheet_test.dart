// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:socialmesh/core/widgets/primary_gradient_button.dart';
import 'package:socialmesh/features/settings/mqtt_topics/mqtt_topic_finder_sheet.dart';
import 'package:socialmesh/features/settings/mqtt_topics/mqtt_topic_sampler.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/providers/connectivity_providers.dart';

class _SilentClient implements MqttSampleClient {
  @override
  set onSubscribed(void Function(String topic) callback) {}
  @override
  set onSubscribeFail(void Function(String topic) callback) {}
  @override
  set onDisconnected(void Function() callback) {}
  @override
  Stream<(String, Uint8List)> get messages => const Stream.empty();
  @override
  Future<void> connect(MqttBrokerSettings settings) async {}
  @override
  void subscribe(String filter) {}
  @override
  void unsubscribe(String filter) {}
  @override
  void disconnect() {}
}

const _settings = MqttBrokerSettings(
  host: 'mqtt.meshtastic.org',
  port: 8883,
  useTls: true,
);

Widget _host({
  required bool online,
  String? regionTopic = 'msh/ANZ',
  required ValueChanged<String?> onResult,
}) => ProviderScope(
  overrides: [isOnlineProvider.overrideWithValue(online)],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData.dark(),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () async {
              final picked = await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (_) => Material(
                    child: MqttTopicFinderSheet(
                      scrollController: ScrollController(),
                      settings: _settings,
                      regionTopic: regionTopic,
                      regionName: 'Australia/NZ',
                      locate: () async => const LatLng(-37.74, 144.96),
                      geocode: (_) async => (state: 'VIC', city: 'Coburg'),
                      samplerFactory: () =>
                          MqttTopicSampler(clientFactory: _SilentClient.new),
                    ),
                  ),
                ),
              );
              onResult(picked);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Future<void> open(WidgetTester tester, Widget host) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(host);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('no region set: says so and offers only a custom topic', (
    tester,
  ) async {
    await open(
      tester,
      _host(online: true, regionTopic: null, onResult: (_) {}),
    );
    expect(find.text(l10n.mqttTopicFinderNoRegion), findsOneWidget);
    expect(find.text(l10n.mqttTopicFinderNearYou), findsNothing);
    expect(find.text(l10n.mqttTopicFinderCustomTopic), findsWidgets);
  });

  testWidgets('offline: says topics need the internet', (tester) async {
    await open(tester, _host(online: false, onResult: (_) {}));
    expect(find.text(l10n.mqttTopicFinderOffline), findsOneWidget);
  });

  testWidgets('the ladder comes from the position and picking fills the '
      'topic', (tester) async {
    String? result;
    await open(tester, _host(online: true, onResult: (r) => result = r));
    expect(find.text('msh/ANZ'), findsOneWidget);
    expect(find.text('msh/ANZ/VIC'), findsOneWidget);
    expect(find.text('msh/ANZ/VIC/coburg'), findsOneWidget);
    expect(
      find.text(
        l10n.mqttTopicFinderRungTitle(l10n.mqttTopicFinderLevelCity, 'Coburg'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('msh/ANZ/VIC/coburg'));
    await tester.pumpAndSettle();
    expect(result, 'msh/ANZ/VIC/coburg');
  });

  testWidgets('a custom topic is checked against the firmware rules', (
    tester,
  ) async {
    String? result;
    await open(tester, _host(online: true, onResult: (r) => result = r));
    PrimaryGradientButton use() => tester.widget<PrimaryGradientButton>(
      find.byType(PrimaryGradientButton),
    );
    expect(use().enabled, isFalse);

    await tester.enterText(find.byType(TextField), 'msh/ANZ/2');
    await tester.pump();
    expect(find.text(l10n.mqttRootTopicProblemEndsWithVersion), findsOneWidget);
    expect(use().enabled, isFalse);

    await tester.enterText(find.byType(TextField), ' msh//ANZ/VIC/ ');
    await tester.pump();
    expect(use().enabled, isTrue);
    await tester.tap(find.byType(PrimaryGradientButton));
    await tester.pumpAndSettle();
    expect(result, 'msh/ANZ/VIC');
  });
}
