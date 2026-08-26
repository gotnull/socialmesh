// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Source-text regressions for [LicenseOrgOverviewCard].
//
// The overview card is the load-bearing surface where owners see
// their community name. Until this slice, an org with no stored
// name surfaced the raw orgId slug ("cleanrun-pack-ten") which is
// internal plumbing. Pin two invariants:
//
//   1. Empty-name display uses a localised placeholder, not the
//      orgId slug.
//   2. The edit-name affordance is owner-gated (admins manage seats
//      via the members sheet but cannot rename the org).
//
// A full widget test that drives the sheet through to a successful
// rename would need a fake CallableInvoker plumbed into the
// AppBottomSheet body, which adds more scaffolding than this slice
// justifies. The service contract (with that fake plumbed) is
// already covered in
// `test/services/license_org/license_org_settings_service_test.dart`.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String src;

  late String labelSrc;

  setUpAll(() {
    src = File(
      'lib/features/license_org/license_org_overview_card.dart',
    ).readAsStringSync();
    // The action->label mapping used to be duplicated in this card and
    // in the audit log screen, and the copies drifted. It now lives in
    // one shared helper, which is where the label assertions belong.
    labelSrc = File(
      'lib/features/license_org/utils/audit_action_label.dart',
    ).readAsStringSync();
  });

  group('LicenseOrgOverviewCard — name display invariants', () {
    test(
      'empty-name fallback uses licenseOrgNameEmptyPlaceholder (not orgId)',
      () {
        expect(src, contains('l10n.licenseOrgNameEmptyPlaceholder'));
        // The old code path emitted the raw orgId slug as the display
        // name. Guard against re-introduction by asserting we do NOT
        // see `: orgId;` as the displayName fallback. The string `orgId`
        // appears legitimately elsewhere (provider lookups, audit log
        // routes), so we bind the negative check to the
        // `displayName` assignment.
        final displayNameIdx = src.indexOf('final displayName =');
        expect(displayNameIdx, greaterThan(-1));
        final semicolonIdx = src.indexOf(';', displayNameIdx);
        final assignmentLine = src.substring(displayNameIdx, semicolonIdx);
        expect(
          assignmentLine,
          isNot(contains(': orgId')),
          reason:
              'displayName must NEVER fall back to the orgId slug — '
              'use l10n.licenseOrgNameEmptyPlaceholder instead.',
        );
      },
    );

    test('hasStoredName guard preserves the real stored name', () {
      // When the org doc has a non-empty name we MUST show it
      // verbatim. The placeholder is the fallback only.
      expect(src, contains('hasStoredName'));
      expect(src, contains('org!.name'));
    });

    test('SectionTitle opts into marquee for user-generated org names', () {
      // The community name can be up to 50 chars; fading the tail
      // ("SAMPLE VOLUNTEER BRIGA…") loses information. Marquee
      // instead so the owner can read their own name in full.
      expect(src, contains('marquee: true'));
    });
  });

  group('LicenseOrgOverviewCard — edit-name affordance gating', () {
    test('edit icon only renders for owner role', () {
      // The trailing IconButton on the SectionTitle must be gated on
      // isOwner so admins / members never see the affordance.
      expect(
        src,
        contains('final isOwner = role == LicenseOrgMemberRole.owner'),
      );
      expect(src, contains('trailing: isOwner'));
    });

    test('edit icon opens the name sheet via _openNameSheet helper', () {
      expect(src, contains('_openNameSheet('));
      expect(src, contains('LicenseOrgSettingsService()'));
      expect(src, contains('_NameOrgSheet'));
    });

    test('passes the current stored name into the sheet (pre-fill)', () {
      // Owners renaming an existing community should not type the
      // name back from scratch. Pre-fill the controller with the
      // current value.
      expect(src, contains('currentName: hasStoredName ? org!.name : \'\''));
      expect(src, contains('TextEditingController(text: widget.currentName)'));
    });
  });

  group('LicenseOrgOverviewCard — sheet validation invariants', () {
    test('TextField sets a maxLength matching the backend cap', () {
      // socialmesh-lint enforces maxLength on every TextField; here
      // we additionally pin that it uses the service constant so
      // backend / client stay in lockstep.
      expect(src, contains('maxLength: licenseOrgNameMaxLength'));
    });

    test(
      'client-side preflight rejects empty and over-long before network',
      () {
        expect(src, contains('l10n.licenseOrgNameValidationEmpty'));
        expect(src, contains('l10n.licenseOrgNameValidationTooLong'));
        // raw.length comparison so the preflight matches the backend's
        // own UTF-16-length check.
        expect(src, contains('raw.length > licenseOrgNameMaxLength'));
      },
    );

    test('snackbar branches: success vs no-change vs error', () {
      expect(
        src,
        contains(
          'showSuccessSnackBar(context, l10n.licenseOrgNameSaveSuccess)',
        ),
      );
      expect(
        src,
        contains('showInfoSnackBar(context, l10n.licenseOrgNameSaveNoChange)'),
      );
      expect(src, contains('showErrorSnackBar(context, _nameErrorMessage'));
    });
  });

  // ===========================================================================
  // Auto-prompt: the owner of a freshly-purchased org sees the name
  // sheet immediately, with session-scoped dismissal tracking so a
  // "Not yet" tap stays sticky for the rest of the app session.
  // ===========================================================================
  group('LicenseOrgOverviewCard — auto-prompt invariants', () {
    test('uses a module-level Set to track per-orgId one-shot state', () {
      // A provider would tempt persistence and make the dismissal
      // permanent across launches. The whole point is to re-nudge
      // on the next launch, so the tracker stays in-memory only.
      expect(src, contains('Set<String> _autoPromptedOrgIds'));
      expect(src, isNot(contains('SharedPreferences')));
    });

    test('exposes a @visibleForTesting reset hook for widget tests', () {
      expect(src, contains('@visibleForTesting'));
      expect(src, contains('debugResetLicenseOrgAutoPromptSet'));
    });

    test('gates on owner + empty-name + active + not-yet-prompted', () {
      // All four conditions must hold to fire. Removing any one
      // would either nag non-owners, fire on already-named orgs,
      // pile a sheet on a suspended org, or re-prompt after dismiss.
      final guard = src.substring(
        src.indexOf('final shouldAutoPromptName ='),
        src.indexOf(';', src.indexOf('final shouldAutoPromptName =')),
      );
      expect(guard, contains('org != null'));
      expect(guard, contains('!hasStoredName'));
      expect(guard, contains('isOwner'));
      expect(guard, contains('status == LicenseOrgStatus.active'));
      expect(guard, contains('!_autoPromptedOrgIds.contains(orgId)'));
    });

    test('marks orgId as prompted BEFORE scheduling the callback', () {
      // The `add` must precede the `addPostFrameCallback` so a
      // second build during the same frame (e.g. provider rebuild
      // mid-render) cannot enqueue two prompts.
      final ifIdx = src.indexOf('if (shouldAutoPromptName)');
      expect(ifIdx, greaterThan(-1));
      final addIdx = src.indexOf('_autoPromptedOrgIds.add(orgId)', ifIdx);
      final scheduleIdx = src.indexOf('addPostFrameCallback', ifIdx);
      expect(addIdx, greaterThan(ifIdx));
      expect(scheduleIdx, greaterThan(addIdx));
    });

    test('schedules via postFrameCallback (not in build inline)', () {
      // Opening a bottom sheet inline from build would assert in
      // the framework. Defer to post-frame so the sheet animates on
      // top of a settled overview.
      expect(src, contains('WidgetsBinding.instance.addPostFrameCallback'));
      expect(src, contains('if (!context.mounted) return;'));
    });

    test('skips suspended orgs (no piling sheets on a paused community)', () {
      // Captured in the guard above, but cross-checked here to lock
      // the invariant explicitly: an org in suspended state must
      // never trigger the auto-prompt.
      expect(src, contains('status == LicenseOrgStatus.active'));
    });
  });

  // ===========================================================================
  // Audit-log icon + label coverage for the rename action. The audit
  // backend emits `license_org_renamed` rows; the overview card's
  // recent-activity strip + the full audit log screen must render
  // them with the dedicated icon + label, not the generic "Other
  // event" fallback.
  // ===========================================================================
  group('LicenseOrgOverviewCard — audit log rename row', () {
    test('icon switch covers LicenseOrgAuditAction.licenseOrgRenamed', () {
      expect(src, contains('case LicenseOrgAuditAction.licenseOrgRenamed:'));
      // The case sits in the _iconFor switch and must return a
      // distinct icon (Icons.edit_outlined matches the trailing
      // edit affordance on the card header).
      expect(src, contains('return Icons.edit_outlined'));
    });

    test(
      'label switch resolves to licenseOrgAuditActionLicenseOrgRenamed l10n key',
      () {
        expect(
          labelSrc,
          contains('l10n.licenseOrgAuditActionLicenseOrgRenamed'),
        );
      },
    );

    test('the card delegates to the one shared label mapping', () {
      // Guards the regression this extraction fixed: a second copy of
      // the switch in the card would silently stop matching the audit
      // screen the next time an action gains real copy.
      expect(src, contains('licenseOrgAuditActionLabel('));
      expect(src, isNot(contains('static String _actionLabel(')));
    });

    test('fleet actions have real labels, not the generic fallback', () {
      // These rendered as "Other event" until the fleet UI shipped.
      for (final key in [
        'licenseOrgAuditActionFleetDeviceEnrolled',
        'licenseOrgAuditActionFleetDeviceUpdated',
        'licenseOrgAuditActionFleetDeviceAssigned',
        'licenseOrgAuditActionFleetDeviceRetired',
        'licenseOrgAuditActionPilotLicenseOrgProvisioned',
      ]) {
        expect(labelSrc, contains('l10n.$key'));
      }
    });
  });

  // ===========================================================================
  // Regression: _openNameSheet must receive orgId as an explicit
  // parameter rather than relying on findAncestorWidgetOfExactType,
  // which walks UP from the calling element and EXCLUDES the
  // starting widget — so calling it from the card's own context
  // resolved to '' silently and the backend rejected with
  // `invalid-argument`. Sim-verified on 2026-05-28: the rename
  // appeared to do nothing (no snackbar, no Firestore write)
  // before this fix landed.
  // ===========================================================================
  group('LicenseOrgOverviewCard — _openNameSheet orgId regression', () {
    test('_openNameSheet signature carries an explicit orgId param', () {
      expect(src, contains('required String orgId,'));
    });

    test('callers pass orgId explicitly (no ancestor-lookup fallback)', () {
      // Both call sites — manual edit-icon tap and auto-prompt
      // post-frame — must include `orgId: orgId,`.
      expect(src, contains('orgId: orgId,'));
      expect(
        src,
        isNot(
          contains('findAncestorWidgetOfExactType<LicenseOrgOverviewCard>'),
        ),
        reason:
            'ancestor lookup was the silent-failure bug; never reintroduce.',
      );
    });

    test(
      'service.updateName receives the captured orgId, not lookup result',
      () {
        expect(src, contains('service.updateName('));
        expect(src, contains('licenseOrgId: orgId,'));
      },
    );
  });
}
