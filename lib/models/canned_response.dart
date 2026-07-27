// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:uuid/uuid.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/l10n_utils.dart';

/// A canned (quick) response for fast messaging
class CannedResponse {
  final String id;
  final String text;
  final int sortOrder;
  final bool isDefault;

  CannedResponse({
    String? id,
    required this.text,
    this.sortOrder = 0,
    this.isDefault = false,
  }) : id = id ?? const Uuid().v4();

  CannedResponse copyWith({
    String? id,
    String? text,
    int? sortOrder,
    bool? isDefault,
  }) {
    return CannedResponse(
      id: id ?? this.id,
      text: text ?? this.text,
      sortOrder: sortOrder ?? this.sortOrder,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'sortOrder': sortOrder,
      'isDefault': isDefault,
    };
  }

  factory CannedResponse.fromJson(Map<String, dynamic> json) {
    return CannedResponse(
      id: json['id'] as String,
      text: json['text'] as String,
      sortOrder: json['sortOrder'] as int? ?? 0,
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }

  @override
  String toString() => 'CannedResponse(text: $text)';
}

/// Default canned responses
class DefaultCannedResponses {
  /// Localised text selectors for the built-in defaults, keyed by their
  /// stable ids as stored in SharedPreferences / cloud sync.
  static final Map<String, String Function(AppLocalizations)>
  _defaultTextSelectors = {
    'default_ok': (l10n) => l10n.cannedResponseOk,
    'default_yes': (l10n) => l10n.cannedResponseYes,
    'default_no': (l10n) => l10n.cannedResponseNo,
    'default_omw': (l10n) => l10n.cannedResponseOnMyWay,
    'default_help': (l10n) => l10n.cannedResponseNeedHelp,
    'default_safe': (l10n) => l10n.cannedResponseImSafe,
    'default_wait': (l10n) => l10n.cannedResponseWaitForMe,
    'default_thanks': (l10n) => l10n.cannedResponseThanks,
  };

  static const List<String> _defaultIdOrder = [
    'default_ok',
    'default_yes',
    'default_no',
    'default_omw',
    'default_help',
    'default_safe',
    'default_wait',
    'default_thanks',
  ];

  static List<CannedResponse> get all {
    final l10n = safeL10n();
    return [
      for (var i = 0; i < _defaultIdOrder.length; i++)
        CannedResponse(
          id: _defaultIdOrder[i],
          text: _defaultTextSelectors[_defaultIdOrder[i]]!(l10n),
          sortOrder: i,
          isDefault: true,
        ),
    ];
  }

  /// Every locale's translation of each built-in default, used to decide
  /// whether a persisted entry is still a stock value.
  static Map<String, Set<String>>? _stockTextsCache;
  static Map<String, Set<String>> get _stockTexts {
    return _stockTextsCache ??= {
      for (final entry in _defaultTextSelectors.entries)
        entry.key: {
          for (final locale in AppLocalizations.supportedLocales)
            entry.value(lookupAppLocalizations(locale)),
        },
    };
  }

  /// The bell-emoji prefix stock Meshtastic clients put in front of the
  /// alert-bell quick reply.
  static const String _bellEmojiPrefix = '\u{1F514}';

  /// Recognised forms of the well-known alert-bell quick reply label,
  /// lowercased. The English base form is included in addition to every
  /// locale's translation because legacy persisted rows froze the
  /// untranslated label.
  static Set<String>? _stockAlertBellTextsCache;
  static Set<String> get _stockAlertBellTexts {
    return _stockAlertBellTextsCache ??= {
      'alert bell character',
      for (final locale in AppLocalizations.supportedLocales)
        lookupAppLocalizations(locale).cannedResponseAlertBell.toLowerCase(),
    };
  }

  /// Re-resolve stock built-in labels in [stored] to the active locale.
  ///
  /// Persisted canned responses freeze their display text at save time in
  /// whatever locale was active. Entries whose text is still a stock value
  /// (it matches the entry's translation in some supported locale) are
  /// system labels, not user content, so they follow the locale. This
  /// covers the built-in defaults (matched by id + stock text) and the
  /// well-known alert-bell label (matched by exact stock text, with or
  /// without the bell-emoji prefix). Edited defaults and genuine
  /// user-created replies are returned untouched.
  static List<CannedResponse> localized(List<CannedResponse> stored) {
    final l10n = safeL10n();
    return [
      for (final response in stored)
        _localizedEntry(l10n, response) ?? response,
    ];
  }

  static CannedResponse? _localizedEntry(
    AppLocalizations l10n,
    CannedResponse response,
  ) {
    final selector = _defaultTextSelectors[response.id];
    if (selector != null &&
        (_stockTexts[response.id]?.contains(response.text.trim()) ?? false)) {
      return response.copyWith(text: selector(l10n));
    }
    final bellText = _localizedAlertBellText(l10n, response.text);
    if (bellText != null) {
      return response.copyWith(text: bellText);
    }
    return null;
  }

  static String? _localizedAlertBellText(AppLocalizations l10n, String text) {
    var candidate = text.trim();
    var hadBellPrefix = false;
    if (candidate.startsWith(_bellEmojiPrefix)) {
      hadBellPrefix = true;
      candidate = candidate.substring(_bellEmojiPrefix.length).trim();
    }
    if (!_stockAlertBellTexts.contains(candidate.toLowerCase())) {
      return null;
    }
    final localizedText = l10n.cannedResponseAlertBell;
    return hadBellPrefix ? '$_bellEmojiPrefix $localizedText' : localizedText;
  }
}
