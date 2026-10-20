// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Notification rendering pipeline with policy-driven length enforcement.
///
/// ## Quick start
///
/// ```dart
/// final spec = NotificationSpec.fromUserTemplate(
///   titleTemplate: '{{node.name}} Alert',
///   bodyTemplate: '{{node.name}} battery at {{battery}} - {{location}}',
/// );
///
/// final result = NotificationRenderer.render(
///   spec: spec,
///   variables: {'node.name': 'Base Camp', 'battery': '12%', ...},
///   policy: NotificationPolicy.strictest,
/// );
///
/// // result.parts.title, result.parts.body are guaranteed within policy.
/// ```
///
/// See `docs/NOTIFICATION_RENDERING.md` for the full guide.
library;

export 'notification_parts.dart';
export 'notification_policy.dart';
export 'notification_renderer.dart';
export 'notification_template.dart';
export 'text_measurement.dart';
