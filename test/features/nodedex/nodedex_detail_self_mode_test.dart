// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// NodeDex Detail screen — self vs remote presentation regression tests.
//
// Pins the self-node presentation contract:
//   1. Self node renders the "This Device" card (no archetype framing).
//   2. Self node never renders trait labels (Ghost / Wanderer / Beacon / ...).
//   3. Self node hides the Encounters and Messages discovery rows and
//      relabels "Last encounter" as "Last sync".
//   4. Remote node still renders archetype/trait copy and the standard
//      Encounters/Messages discovery rows.
//
// Backed by nodeDexIsSelfProvider as the single authority — never compare
// nodeNum to myNodeNum inline. Provider-level coverage lives in
// nodedex_provider_test.dart.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/features/nodedex/models/nodedex_entry.dart';
import 'package:socialmesh/features/nodedex/models/node_activity_event.dart';
import 'package:socialmesh/features/nodedex/providers/nodedex_providers.dart';
import 'package:socialmesh/features/nodedex/screens/nodedex_detail_screen.dart';
import 'package:socialmesh/features/nodedex/services/nodedex_database.dart';
import 'package:socialmesh/features/nodedex/services/nodedex_sqlite_store.dart';
import 'package:socialmesh/features/nodedex/services/sigil_generator.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/providers/accessibility_providers.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/cloud_sync_entitlement_providers.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final _l10n = AppLocalizationsEn();

// ---------------------------------------------------------------------------
// Minimal fakes (mirrored from nodedex_provider_test.dart)
// ---------------------------------------------------------------------------

class _FakeTransport extends DeviceTransport {
  @override
  TransportType get type => TransportType.ble;
  @override
  bool get requiresFraming => false;
  @override
  bool get requiresWakeSequence => false;
  @override
  TransportReconnectMode get reconnectMode => TransportReconnectMode.scanBased;
  @override
  DeviceConnectionState get state => DeviceConnectionState.disconnected;
  final StreamController<DeviceConnectionState> _stateCtrl =
      StreamController<DeviceConnectionState>.broadcast();
  @override
  Stream<DeviceConnectionState> get stateStream => _stateCtrl.stream;
  @override
  Stream<List<int>> get dataStream => const Stream.empty();
  @override
  Stream<DeviceInfo> scan({Duration? timeout, bool scanAll = false}) =>
      const Stream.empty();
  @override
  Future<void> connect(DeviceInfo device) async {}
  @override
  Future<void> disconnect() async {}
  @override
  Future<void> enableNotifications() async {}
  @override
  Future<void> pollOnce() async {}
  @override
  Future<void> send(List<int> data) async {}
  @override
  Future<int?> readRssi() async => null;
  @override
  Future<void> dispose() async {
    await _stateCtrl.close();
  }
}

class _StaticNodesNotifier extends NodesNotifier {
  _StaticNodesNotifier(this._initial);
  final Map<int, MeshNode> _initial;
  @override
  Map<int, MeshNode> build() => _initial;
}

class _StaticMyNodeNumNotifier extends MyNodeNumNotifier {
  _StaticMyNodeNumNotifier(this._initial);
  final int? _initial;
  @override
  int? build() => _initial;
}

// Skips NodeDexNotifier's async storage init + periodic co-seen flush timer
// so the screen sees the seeded map on the first build (the real init path
// returns {} synchronously and only populates after an async storage load,
// which races widget-test pump cycles).
class _StaticNodeDexNotifier extends NodeDexNotifier {
  _StaticNodeDexNotifier(this._initial);
  final Map<int, NodeDexEntry> _initial;
  @override
  Map<int, NodeDexEntry> build() => _initial;
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const int _myNodeNum = 99999;
const int _remoteNodeNum = 12345;

NodeDexEntry _entry(
  int nodeNum, {
  DateTime? firstUsedAt,
  DateTime? lastUsedAt,
}) {
  // Use a fixed clock-independent timestamp so date formatting is stable.
  final firstSeen = DateTime(2025, 1, 1, 12, 0);
  final lastSeen = DateTime(2025, 1, 14, 15, 30);
  return NodeDexEntry(
    nodeNum: nodeNum,
    firstSeen: firstSeen,
    lastSeen: lastSeen,
    encounterCount: 1,
    sigil: SigilGenerator.generate(nodeNum),
    firstUsedAt: firstUsedAt,
    lastUsedAt: lastUsedAt,
  );
}

MeshNode _node(int nodeNum) {
  return MeshNode(nodeNum: nodeNum, lastHeard: DateTime(2025, 1, 14, 15, 30));
}

Widget _wrap({
  required int nodeNum,
  required NodeDexSqliteStore store,
  required int? myNodeNum,
  Map<int, NodeDexEntry>? entriesOverride,
}) {
  // Pre-build the entry map so the static notifier returns it on first build.
  final entries =
      entriesOverride ??
      <int, NodeDexEntry>{
        _myNodeNum: _entry(_myNodeNum),
        _remoteNodeNum: _entry(_remoteNodeNum),
      };

  return ProviderScope(
    overrides: [
      nodesProvider.overrideWith(
        () => _StaticNodesNotifier({nodeNum: _node(nodeNum)}),
      ),
      myNodeNumProvider.overrideWith(() => _StaticMyNodeNumNotifier(myNodeNum)),
      nodeDexStoreProvider.overrideWith((ref) => store),
      // Static map → no async storage init, no periodic timers, screen sees
      // the entry on first build instead of racing against the async load.
      nodeDexProvider.overrideWith(() => _StaticNodeDexNotifier(entries)),
      // The activity timeline provider hits SQL via nodeDexStoreProvider —
      // override to a synchronous empty list so no sqflite timer leaks past
      // tearDown. The timeline UI is not under test here.
      nodeActivityTimelineProvider(
        nodeNum,
      ).overrideWith((ref) => Future<List<NodeActivityEvent>>.value(const [])),
      canCloudSyncWriteProvider.overrideWithValue(false),
      protocolServiceProvider.overrideWithValue(
        ProtocolService(_FakeTransport()),
      ),
      // Skip _DetailEntrance entrance-stagger animations so no Future.delayed
      // timers stay pending past tearDown.
      reduceMotionEnabledProvider.overrideWithValue(true),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(),
      home: NodeDexDetailScreen(nodeNum: nodeNum),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  // A single pump is enough now that nodeDexProvider is synchronous; an
  // extra small pump lets derived providers compute from the seeded map.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late NodeDexSqliteStore store;
  late NodeDexDatabase db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    NodeDexNotifier.encounterCooldownOverride = Duration.zero;
    // Long enough that the periodic co-seen flush timer never fires during
    // the test — leaving it on a 50ms tick wedges the pending-timer guard
    // at tearDown.
    NodeDexNotifier.coSeenFlushIntervalOverride = const Duration(hours: 1);
  });

  setUp(() async {
    db = NodeDexDatabase(dbPathOverride: inMemoryDatabasePath);
    store = NodeDexSqliteStore(db, saveDebounceDuration: Duration.zero);
    await store.init();
    // Seed both fixtures so nodedex_provider loads them on init.
    await store.saveEntryImmediate(_entry(_myNodeNum));
    await store.saveEntryImmediate(_entry(_remoteNodeNum));
  });

  tearDown(() async {
    await store.dispose();
  });

  tearDownAll(() {
    NodeDexNotifier.resetTestOverrides();
  });

  // Use a wide phone-sized viewport to maximize the chance that off-screen
  // sliver content renders within the view; the tests assert on text that
  // appears in the scroll-view; some content may not paint, but the strings
  // we care about (discovery rows + trait/self card) live near the top.
  Future<void> setUpViewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
  }

  group('NodeDexDetailScreen — self mode', () {
    testWidgets(
      'renders the "This Device" card and not the trait/Ghost framing',
      (tester) async {
        await setUpViewport(tester);

        await tester.pumpWidget(
          _wrap(nodeNum: _myNodeNum, store: store, myNodeNum: _myNodeNum),
        );
        await _settle(tester);

        // SectionTitle uppercases its title — assert against the rendered
        // uppercased form rather than the raw ARB value.
        expect(
          find.text(_l10n.nodedexSelfDeviceTitle.toUpperCase()),
          findsOneWidget,
          reason: 'self-mode card title must appear',
        );
        expect(
          find.text(_l10n.nodedexSelfDeviceSubtitle),
          findsOneWidget,
          reason: 'self-mode card subtitle must appear',
        );
      },
    );

    testWidgets('hides Encounters and Messages discovery rows for self', (
      tester,
    ) async {
      await setUpViewport(tester);

      await tester.pumpWidget(
        _wrap(nodeNum: _myNodeNum, store: store, myNodeNum: _myNodeNum),
      );
      await _settle(tester);

      expect(
        find.text(_l10n.nodedexEncountersLabel),
        findsNothing,
        reason: 'self must not render the Encounters discovery row',
      );
      expect(
        find.text(_l10n.nodedexMessagesLabel),
        findsNothing,
        reason: 'self must not render the Messages discovery row',
      );
    });

    testWidgets('renames "Last encounter" to "Last sync" for self', (
      tester,
    ) async {
      await setUpViewport(tester);

      await tester.pumpWidget(
        _wrap(nodeNum: _myNodeNum, store: store, myNodeNum: _myNodeNum),
      );
      await _settle(tester);

      expect(
        find.text(_l10n.nodedexSelfLastSyncLabel),
        findsOneWidget,
        reason: 'self must render the "Last sync" label in DiscoveryStats',
      );
      expect(
        find.text(_l10n.nodedexLastSeen),
        findsNothing,
        reason: 'self must not render the remote-peer "Last encounter" label',
      );
    });
  });

  group('NodeDexDetailScreen — remote mode (regression)', () {
    testWidgets('still renders Encounters and Messages discovery rows', (
      tester,
    ) async {
      await setUpViewport(tester);

      await tester.pumpWidget(
        _wrap(nodeNum: _remoteNodeNum, store: store, myNodeNum: _myNodeNum),
      );
      await _settle(tester);

      expect(
        find.text(_l10n.nodedexEncountersLabel),
        findsOneWidget,
        reason: 'remote must still render the Encounters discovery row',
      );
      expect(
        find.text(_l10n.nodedexMessagesLabel),
        findsOneWidget,
        reason: 'remote must still render the Messages discovery row',
      );
      expect(
        find.text(_l10n.nodedexLastSeen),
        findsOneWidget,
        reason: 'remote must still render the "Last encounter" label',
      );
    });

    testWidgets('does not render the self-mode "This Device" card for remote', (
      tester,
    ) async {
      await setUpViewport(tester);

      await tester.pumpWidget(
        _wrap(nodeNum: _remoteNodeNum, store: store, myNodeNum: _myNodeNum),
      );
      await _settle(tester);

      expect(
        find.text(_l10n.nodedexSelfDeviceTitle.toUpperCase()),
        findsNothing,
        reason: 'remote must not render the self-device card',
      );
      expect(
        find.text(_l10n.nodedexSelfLastSyncLabel),
        findsNothing,
        reason: 'remote must not render the self-mode "Last sync" label',
      );
    });
  });

  // ===========================================================================
  // Connection-identity row rendering (firstUsedAt / lastUsedAt)
  //
  // Per the plan: rows are hidden when null (no em-dash placeholder, since
  // empty would feel broken on entries that were self before this feature
  // shipped) and rendered when populated. Remote entries never have these
  // fields set, so the rows must never appear there.
  // ===========================================================================

  group('NodeDexDetailScreen — connection-identity rows', () {
    testWidgets(
      'self mode renders First used + Last used rows when fields are set',
      (tester) async {
        await setUpViewport(tester);

        final firstUsed = DateTime(2026, 4, 30, 23, 14);
        final lastUsed = DateTime(2026, 5, 4, 9, 2);
        final entries = <int, NodeDexEntry>{
          _myNodeNum: _entry(
            _myNodeNum,
            firstUsedAt: firstUsed,
            lastUsedAt: lastUsed,
          ),
          _remoteNodeNum: _entry(_remoteNodeNum),
        };

        await tester.pumpWidget(
          _wrap(
            nodeNum: _myNodeNum,
            store: store,
            myNodeNum: _myNodeNum,
            entriesOverride: entries,
          ),
        );
        await _settle(tester);

        expect(
          find.text(_l10n.nodedexFirstUsedLabel),
          findsOneWidget,
          reason: 'self with firstUsedAt set must render the First used row',
        );
        expect(
          find.text(_l10n.nodedexLastUsedLabel),
          findsOneWidget,
          reason: 'self with lastUsedAt set must render the Last used row',
        );
      },
    );

    testWidgets(
      'self mode HIDES First used + Last used rows when fields are null',
      (tester) async {
        await setUpViewport(tester);

        // Default fixture leaves firstUsedAt and lastUsedAt null.
        await tester.pumpWidget(
          _wrap(nodeNum: _myNodeNum, store: store, myNodeNum: _myNodeNum),
        );
        await _settle(tester);

        expect(
          find.text(_l10n.nodedexFirstUsedLabel),
          findsNothing,
          reason: 'null firstUsedAt must not render an em-dash placeholder',
        );
        expect(
          find.text(_l10n.nodedexLastUsedLabel),
          findsNothing,
          reason: 'null lastUsedAt must not render an em-dash placeholder',
        );
      },
    );

    testWidgets('remote mode never renders First used / Last used rows', (
      tester,
    ) async {
      await setUpViewport(tester);

      // Even with the timestamps populated on the remote entry (which
      // shouldn't happen in production, but pin it as a UI gate so a
      // future bug can't smuggle these rows into a remote screen).
      final firstUsed = DateTime(2026, 4, 30, 23, 14);
      final lastUsed = DateTime(2026, 5, 4, 9, 2);
      final entries = <int, NodeDexEntry>{
        _myNodeNum: _entry(_myNodeNum),
        _remoteNodeNum: _entry(
          _remoteNodeNum,
          firstUsedAt: firstUsed,
          lastUsedAt: lastUsed,
        ),
      };

      await tester.pumpWidget(
        _wrap(
          nodeNum: _remoteNodeNum,
          store: store,
          myNodeNum: _myNodeNum,
          entriesOverride: entries,
        ),
      );
      await _settle(tester);

      expect(
        find.text(_l10n.nodedexFirstUsedLabel),
        findsNothing,
        reason: 'remote must never render the First used row',
      );
      expect(
        find.text(_l10n.nodedexLastUsedLabel),
        findsNothing,
        reason: 'remote must never render the Last used row',
      );
    });

    testWidgets('self mode hides First Discovered + Known For rows '
        '(replaced by First used / Last used)', (tester) async {
      await setUpViewport(tester);

      await tester.pumpWidget(
        _wrap(nodeNum: _myNodeNum, store: store, myNodeNum: _myNodeNum),
      );
      await _settle(tester);

      expect(
        find.text(_l10n.nodedexFirstDiscovered),
        findsNothing,
        reason:
            'self mode must hide the mesh-observation '
            '"First Discovered" row',
      );
      expect(
        find.text(_l10n.nodedexKnownFor),
        findsNothing,
        reason: 'self mode must hide the mesh-observation "Known For" row',
      );
    });

    testWidgets('remote mode still renders First Discovered + Known For rows', (
      tester,
    ) async {
      await setUpViewport(tester);

      await tester.pumpWidget(
        _wrap(nodeNum: _remoteNodeNum, store: store, myNodeNum: _myNodeNum),
      );
      await _settle(tester);

      expect(
        find.text(_l10n.nodedexFirstDiscovered),
        findsOneWidget,
        reason: 'remote must still render the First Discovered row',
      );
      expect(
        find.text(_l10n.nodedexKnownFor),
        findsOneWidget,
        reason: 'remote must still render the Known For row',
      );
    });
  });
}
