// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import '../../utils/number_format.dart';

/// Convenience extension on [BuildContext] for accessing [AppLocalizations].
///
/// Usage:
/// ```dart
/// Text(context.l10n.commonCancel)
/// ```
///
/// This is equivalent to `AppLocalizations.of(context)!` but shorter and
/// more readable at every callsite.
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// [value] grouped the way the ARB count placeholders group it, so a
  /// count drawn outside a translated string matches the ones inside:
  /// 20,004 in English, 20.004 in German.
  String formatCount(int value) =>
      NumberFormatUtils.formatWithThousandsSeparators(value, l10n.localeName);
}
