// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import '../l10n/app_localizations.dart';

/// The name shown for a channel: its own [name] when it has one, otherwise
/// the localised default, "Primary Channel" for index 0 and "Channel N" for
/// the others. Firmware leaves the primary channel unnamed by default, so an
/// empty or whitespace-only name is common and must never reach a label.
String channelDisplayName(
  AppLocalizations l10n, {
  required int index,
  required String name,
}) {
  if (name.trim().isNotEmpty) return name;
  return index == 0
      ? l10n.channelsPrimaryChannelName
      : l10n.channelsDefaultChannelName(index);
}
