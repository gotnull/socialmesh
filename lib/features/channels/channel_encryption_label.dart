// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/widgets.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../models/mesh_models.dart';

/// The name shown for a channel's [ChannelEncryption] in the channel list,
/// its options sheet and its QR share sheet.
String channelEncryptionLabel(
  BuildContext context,
  ChannelEncryption encryption,
) => switch (encryption) {
  ChannelEncryption.none => context.l10n.channelsTileNoEncryption,
  ChannelEncryption.publicKey => context.l10n.channelsTileDefaultKey,
  ChannelEncryption.privateKey => context.l10n.channelsTileEncrypted,
};
