// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:open_mail_launcher/open_mail_launcher.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/l10n/l10n_extension.dart';
import '../core/theme.dart';
import '../core/widgets/app_bottom_sheet.dart';
import 'snackbar.dart';

abstract class EmailAppsProbe {
  Future<List<MailApp>> getMailApps();
  Future<bool> openSpecific(MailApp app, EmailContent content);
  Future<bool> launchMailto(Uri uri);
}

class _PlatformEmailAppsProbe implements EmailAppsProbe {
  const _PlatformEmailAppsProbe();

  @override
  Future<List<MailApp>> getMailApps() => OpenMailLauncher.getMailApps();

  @override
  Future<bool> openSpecific(MailApp app, EmailContent content) =>
      OpenMailLauncher.openSpecificMailApp(mailApp: app, emailContent: content);

  @override
  Future<bool> launchMailto(Uri uri) async {
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

EmailAppsProbe _probe = const _PlatformEmailAppsProbe();

@visibleForTesting
void setEmailAppsProbeForTest(EmailAppsProbe probe) {
  _probe = probe;
}

@visibleForTesting
void resetEmailAppsProbeForTest() {
  _probe = const _PlatformEmailAppsProbe();
}

Future<void> launchEmailCompose({
  required BuildContext context,
  required String to,
  String? subject,
  String? body,
}) async {
  final content = EmailContent(to: [to], subject: subject, body: body);

  List<MailApp> apps = const [];
  try {
    apps = _dedupeApps(await _probe.getMailApps());
  } catch (_) {
    apps = const [];
  }

  if (!context.mounted) return;

  if (apps.isEmpty) {
    final ok = await _probe.launchMailto(Uri.parse(content.toMailtoUri()));
    if (!context.mounted) return;
    if (!ok) {
      showErrorSnackBar(context, context.l10n.emailLauncherNoAppsInstalled);
    }
    return;
  }

  final selected = apps.length == 1
      ? apps.first
      : await _showEmailPicker(context: context, apps: apps);

  if (selected == null || !context.mounted) return;

  final ok = await _probe.openSpecific(selected, content);
  if (!context.mounted) return;
  if (!ok) {
    showErrorSnackBar(context, context.l10n.emailLauncherUnableToOpen);
  }
}

List<MailApp> _dedupeApps(List<MailApp> apps) {
  final seen = <String>{};
  final out = <MailApp>[];
  for (final app in apps) {
    final key = app.name.toLowerCase().trim();
    if (seen.add(key)) out.add(app);
  }
  return out;
}

String? _assetForMailApp(MailApp app) {
  final id = app.id.toLowerCase();
  if (id.startsWith('mailto') || id.startsWith('message')) {
    return 'assets/email_apps/apple_mail.png';
  }
  if (id.contains('googlegmail')) return 'assets/email_apps/gmail.png';
  if (id.contains('ms-outlook')) return 'assets/email_apps/outlook.png';
  if (id.contains('ymail')) return 'assets/email_apps/yahoo.png';
  if (id.contains('readdle-spark')) return 'assets/email_apps/spark.png';
  if (id.contains('protonmail')) return 'assets/email_apps/protonmail.png';
  if (id.contains('airmail')) return 'assets/email_apps/airmail.png';
  if (id.contains('fastmail')) return 'assets/email_apps/fastmail.png';
  if (id.contains('superhuman')) return 'assets/email_apps/superhuman.png';
  if (id.contains('hey')) return 'assets/email_apps/hey.png';
  if (id.contains('canarymail')) return 'assets/email_apps/canarymail.png';
  if (id.contains('spike')) return 'assets/email_apps/spike.png';
  if (id.contains('bluemail')) return 'assets/email_apps/bluemail.png';
  if (id.contains('edison')) return 'assets/email_apps/edison.png';
  return null;
}

Future<MailApp?> _showEmailPicker({
  required BuildContext context,
  required List<MailApp> apps,
}) {
  return AppBottomSheet.show<MailApp>(
    context: context,
    child: _EmailAppPicker(apps: apps),
  );
}

class _EmailAppPicker extends StatelessWidget {
  const _EmailAppPicker({required this.apps});

  final List<MailApp> apps;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            0,
            AppTheme.spacing8,
            0,
            AppTheme.spacing16,
          ),
          child: Text(
            context.l10n.emailLauncherChooseApp,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ...apps.map(
          (app) => _EmailAppTile(
            app: app,
            onTap: () => Navigator.of(context).pop(app),
          ),
        ),
      ],
    );
  }
}

class _EmailAppTile extends StatelessWidget {
  const _EmailAppTile({required this.app, required this.onTap});

  final MailApp app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacing8),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing16,
              vertical: AppTheme.spacing12,
            ),
            child: Row(
              children: [
                _AppIcon(app: app),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Text(
                    app.name,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (app.isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing8,
                      vertical: AppTheme.spacing4,
                    ),
                    decoration: BoxDecoration(
                      color: context.accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                    ),
                    child: Text(
                      context.l10n.emailLauncherDefaultBadge,
                      style: TextStyle(
                        color: context.accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.app});

  static const double _size = 40;

  final MailApp app;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: context.accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
      ),
      child: Icon(Icons.email_outlined, color: context.accentColor, size: 22),
    );

    final asset = _assetForMailApp(app);
    if (asset != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        child: Image.asset(
          asset,
          width: _size,
          height: _size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _bytesOrFallback(fallback),
        ),
      );
    }
    return _bytesOrFallback(fallback);
  }

  Widget _bytesOrFallback(Widget fallback) {
    final bytes = _decodeIcon(app.icon);
    if (bytes == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radius8),
      child: Image.memory(
        bytes,
        width: _size,
        height: _size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }

  static Uint8List? _decodeIcon(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      if (raw.startsWith('data:')) {
        return Uri.parse(raw).data?.contentAsBytes();
      }
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }
}
