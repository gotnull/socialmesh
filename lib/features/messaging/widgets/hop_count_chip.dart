// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import '../../../l10n/app_localizations.dart';

// Shared "Direct / N hops" label for a message's hop count. A hop count of
// 0 means the sender was in direct radio range (no relay); anything higher
// is the number of times the message was relayed before arriving. Routing
// all hop-label sites through this helper keeps the wording identical across
// the in-bubble metadata line, the on-tap tech-info panel, and the
// long-press details sheet.
String hopCountLabel(AppLocalizations l10n, int hopCount) => hopCount == 0
    ? l10n.messagingTechInfoDirectHop
    : l10n.messagingTechInfoHops(hopCount);
