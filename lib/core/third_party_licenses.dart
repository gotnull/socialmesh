// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'logging.dart';

// Flutter's LicensePage only auto-collects the LICENSE files of pub
// packages (via the build-generated NOTICES asset). Material bundled
// directly into the app never reaches that surface, so its notices are
// registered here instead: the OFL-1.1 fonts shipped in assets/fonts/,
// the vendored Codec2 library (LGPL-2.1+) whose binaries ship on every
// mobile platform, the vendored vs_node_view package, and the Meshtastic
// protobuf attribution. Each entry's text lives in assets/licenses/.

typedef _BundledNotice = ({String asset, List<String> packages});

const List<_BundledNotice> _bundledNotices = [
  (asset: 'assets/licenses/Inter-OFL.txt', packages: ['Inter (font)']),
  (
    asset: 'assets/licenses/JetBrainsMono-OFL.txt',
    packages: ['JetBrains Mono (font)'],
  ),
  (asset: 'assets/licenses/Caveat-OFL.txt', packages: ['Caveat (font)']),
  (
    asset: 'assets/licenses/codec2-LGPL-2.1.txt',
    packages: ['Codec2 (speech codec)'],
  ),
  (
    asset: 'assets/licenses/vs_node_view-LICENSE.txt',
    packages: ['vs_node_view'],
  ),
  (
    asset: 'assets/licenses/meshtastic-protobufs-NOTICE.txt',
    packages: ['Meshtastic protobufs'],
  ),
];

/// Registers license notices for third-party material that is bundled
/// with the app outside the pub dependency graph.
///
/// Call once before `runApp`. Registration is cheap: the registry stores
/// a lazy producer, and the asset texts are only loaded when the
/// LicensePage (Settings > Open Source) is actually opened.
void registerThirdPartyLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final notice in _bundledNotices) {
      String text;
      try {
        text = await rootBundle.loadString(notice.asset);
      } catch (e) {
        // A missing or unreadable asset must not break the entire
        // license page; surface the failure in logs and keep going.
        AppLogging.platform('licenses: failed to load ${notice.asset}: $e');
        continue;
      }
      yield LicenseEntryWithLineBreaks(notice.packages, text);
    }
  });
}
