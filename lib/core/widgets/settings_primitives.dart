// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';

import '../theme.dart';

/// Canonical inner-settings section header.
///
/// 12px bold, [BuildContext.textTertiary], `letterSpacing: 1.2`, padding
/// `EdgeInsets.fromLTRB(16, 8, 16, 8)`. Use above a [FieldGroupCard] or a
/// run of [SettingsTile]s in form-style screens (settings, configs,
/// admin, wizards). The wider `docs/CODING_PATTERNS.md` reference calls
/// this `_SectionHeader`; the gold-standard call site is
/// `lib/features/settings/mqtt_config_screen.dart`.
///
/// Distinct from `SectionTitle` (in `section_header.dart`), which is for
/// uppercase labels above an `InfoTable` and uses different padding /
/// weight / letterSpacing. Form sections own their own horizontal
/// padding; data tables sit inside an outer Padding that already does.
class SettingsSectionHeader extends StatelessWidget {
  final String title;

  const SettingsSectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 8, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: context.textTertiary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// Canonical inner-settings tile.
///
/// `context.card` background, `radius12`, margin
/// `EdgeInsets.symmetric(horizontal: 16, vertical: 2)`, padding
/// `EdgeInsets.symmetric(horizontal: 16, vertical: 12)`. Renders an
/// icon, a title (`fontSize: 15`, `FontWeight.w500`, `textPrimary`), an
/// optional subtitle (`bodySmallStyle` in `textTertiary`), and an
/// optional trailing widget (typically a `ThemedSwitch` or chevron).
///
/// When [onTap] is non-null, the tile becomes tappable with an InkWell
/// ripple — use this shape for navigation/action rows (e.g. "Reboot
/// device", "Send advertisement"). When [onTap] is null, the tile is a
/// passive container — use this shape for toggle rows whose interactive
/// element is a [trailing] [ThemedSwitch].
///
/// Pair with `ThemedSwitch` for toggles — never raw `Switch`. Gold-
/// standard call sites: `lib/features/settings/mqtt_config_screen.dart`
/// (toggles) and the MeshCore settings screen (action tiles).
class SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const SettingsTile({
    super.key,
    required this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: iconColor ?? context.textSecondary),
          SizedBox(width: AppTheme.spacing16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: context.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppTheme.spacing2),
                  Text(
                    subtitle!,
                    style: context.bodySmallStyle?.copyWith(
                      color: context.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: onTap == null
          ? body
          : Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppTheme.radius12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(AppTheme.radius12),
                child: body,
              ),
            ),
    );
  }
}

/// Canonical inner-settings grouped field card.
///
/// `context.card` background, `radius12`, default margin
/// `EdgeInsets.symmetric(horizontal: 16, vertical: 2)` and padding
/// `EdgeInsets.all(AppTheme.spacing16)`. Used to group several
/// related `TextField`s (typically separated by `SizedBox(height:
/// AppTheme.spacing16)`) under a [SettingsSectionHeader] in form-style
/// screens.
///
/// `margin` and `padding` are overridable for the rare callers that need
/// extra breathing room (e.g. the privacy/consent block in MQTT's map-
/// reporting section uses `vertical: 8` margin). Default values match
/// the canonical pattern.
class FieldGroupCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;

  const FieldGroupCard({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    this.padding = const EdgeInsets.all(AppTheme.spacing16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: child,
    );
  }
}

/// Canonical InputDecoration prefixIcon wrapper.
///
/// Default Material `prefixIcon` sits inside a 48-wide constraint box
/// whose icon-center lands ~12px right of the canonical inner-settings
/// origin. In screens where a [TextField] inside [FieldGroupCard] sits
/// directly above or below a [SettingsTile], the visual offset between
/// the prefix icon and the tile's leading icon is conspicuous.
///
/// Use this wrapper plus [canonicalPrefixIconConstraints] on every
/// `InputDecoration` in form-style settings screens so the prefix icon
/// lines up with [SettingsTile.icon] on the same vertical column.
///
/// ```dart
/// InputDecoration(
///   prefixIcon: canonicalPrefixIcon(
///     Icon(Icons.tag_rounded, color: context.textSecondary),
///   ),
///   prefixIconConstraints: canonicalPrefixIconConstraints,
///   ...
/// )
/// ```
Widget canonicalPrefixIcon(Widget icon) {
  return Padding(
    padding: const EdgeInsets.only(right: AppTheme.spacing12),
    child: icon,
  );
}

/// Companion `prefixIconConstraints` for [canonicalPrefixIcon]. Sets
/// `minWidth: 0` so the prefix area collapses to the icon's natural
/// width plus the trailing breathing-room padding, putting the
/// icon-center at the canonical inner-settings origin.
const BoxConstraints canonicalPrefixIconConstraints = BoxConstraints(
  minWidth: 0,
  minHeight: 24,
);
