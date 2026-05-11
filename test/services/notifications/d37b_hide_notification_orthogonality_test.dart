// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D37-B-A - hide / mute orthogonality from the notification gate's
// perspective. Hide is intentionally NOT a notification gate input.
//
// The gate in `_maybeNotifyChannelMessage` reads the muted set only
// (`meshCoreChannelMutedSetProvider`). It does NOT read
// `meshCoreChannelHiddenSetProvider`. These tests pin that contract:
//   - hidden + unmuted -> notification delivered (decision matrix only,
//     since we can't intercept the platform NotificationService here).
//   - muted + hidden   -> notification suppressed (D37-A behaviour).
//   - hidden alone never reaches the suppression branch.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';

ProviderContainer _container({required String pubKeyPrefix}) {
  return ProviderContainer(
    overrides: [
      meshCoreSelfPubKeyPrefixProvider.overrideWith((ref) => pubKeyPrefix),
    ],
  );
}

Future<void> _pumpPrefsLoad() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'hidden + unmuted: gate would deliver (muted set excludes idx)',
    () async {
      final c = _container(pubKeyPrefix: '79426d8d');
      addTearDown(c.dispose);
      c.read(meshCoreChannelMutedSetProvider);
      await _pumpPrefsLoad();
      await c.read(meshCoreChannelPrefsProvider.notifier).hide(3);
      expect(c.read(meshCoreChannelHiddenSetProvider).contains(3), isTrue);
      expect(
        c.read(meshCoreChannelMutedSetProvider).contains(3),
        isFalse,
        reason:
            'hide alone must not populate the muted set; '
            'gate would deliver',
      );
    },
  );

  test(
    'muted + hidden: gate suppresses (muted set contains idx; D37-A path)',
    () async {
      final c = _container(pubKeyPrefix: '79426d8d');
      addTearDown(c.dispose);
      c.read(meshCoreChannelMutedSetProvider);
      await _pumpPrefsLoad();
      final notifier = c.read(meshCoreChannelPrefsProvider.notifier);
      await notifier.hide(3);
      await notifier.mute(3);
      expect(c.read(meshCoreChannelHiddenSetProvider).contains(3), isTrue);
      expect(c.read(meshCoreChannelMutedSetProvider).contains(3), isTrue);
    },
  );

  test(
    'un-hidden but muted: muted is still the only suppression knob',
    () async {
      final c = _container(pubKeyPrefix: '79426d8d');
      addTearDown(c.dispose);
      c.read(meshCoreChannelMutedSetProvider);
      await _pumpPrefsLoad();
      final notifier = c.read(meshCoreChannelPrefsProvider.notifier);
      await notifier.hide(3);
      await notifier.mute(3);
      // Unhide. Muted state must remain.
      await notifier.unhide(3);
      expect(c.read(meshCoreChannelHiddenSetProvider).contains(3), isFalse);
      expect(c.read(meshCoreChannelMutedSetProvider).contains(3), isTrue);
    },
  );

  test('un-muted but hidden: gate must deliver', () async {
    final c = _container(pubKeyPrefix: '79426d8d');
    addTearDown(c.dispose);
    c.read(meshCoreChannelMutedSetProvider);
    await _pumpPrefsLoad();
    final notifier = c.read(meshCoreChannelPrefsProvider.notifier);
    await notifier.mute(3);
    await notifier.hide(3);
    // Unmute. Hidden state must remain.
    await notifier.unmute(3);
    expect(c.read(meshCoreChannelHiddenSetProvider).contains(3), isTrue);
    expect(c.read(meshCoreChannelMutedSetProvider).contains(3), isFalse);
  });

  test('hide is not a notification gate input - the two providers expose '
      'independent surfaces', () async {
    // Pin the orthogonality contract: muted and hidden are exposed
    // via distinct providers. Populating one must NEVER bleed into
    // the other. This is what guarantees the notification gate can
    // not accidentally consult the hidden set by reading the wrong
    // provider name.
    final c = _container(pubKeyPrefix: '79426d8d');
    addTearDown(c.dispose);
    c.read(meshCoreChannelMutedSetProvider);
    await _pumpPrefsLoad();

    final notifier = c.read(meshCoreChannelPrefsProvider.notifier);
    await notifier.hide(0);
    await notifier.hide(1);
    await notifier.hide(2);

    expect(c.read(meshCoreChannelHiddenSetProvider), equals({0, 1, 2}));
    expect(
      c.read(meshCoreChannelMutedSetProvider),
      isEmpty,
      reason:
          'populating the hidden set must NOT bleed into the muted '
          'set; the notification gate consults muted only',
    );
  });
}
