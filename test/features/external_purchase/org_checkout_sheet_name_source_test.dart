// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Source-text regressions for the mandatory-name slice on
// [showOrgCheckoutSheet]. The buy sheet must:
//   - render a Name field above the Group ID field
//   - auto-derive the slug from the Name until the user manually
//     edits the slug (then leave it alone)
//   - validate name (1..50 chars, non-empty) BEFORE submit
//   - pass `licenseOrgName` into `service.createCheckout`
//   - map server `license-org-name-*` rejection reasons to copy
//
// Source-text vs widget test: a live widget test would need a stubbed
// callable invoker plus a stubbed Stripe launcher, both of which the
// production code resolves through Riverpod. The contract here is
// narrow (10 invariants) and stable enough to pin via regex.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String src;

  setUpAll(() {
    src = File(
      'lib/features/external_purchase/org_checkout_sheet.dart',
    ).readAsStringSync();
  });

  group('Buy sheet — mandatory name field', () {
    test('declares a separate _nameController + _nameFocusNode', () {
      // Two TextEditingController instances total: one for the
      // display Name, one for the Group ID slug. Sharing a single
      // controller would couple their text state and make
      // auto-derive impossible.
      expect(src, contains('final _nameController = TextEditingController()'));
      expect(src, contains('final _nameFocusNode = FocusNode()'));
    });

    test('disposes both controllers + focus nodes', () {
      // Memory leak guard: every TextEditingController and FocusNode
      // owned by the state must be disposed. The original sheet
      // already does this for slug; adding a second pair without
      // disposing them is a classic regression.
      expect(src, contains('_nameController.dispose()'));
      expect(src, contains('_nameFocusNode.dispose()'));
    });

    test('auto-derive slug from name until user edits slug manually', () {
      // The slug field is seeded from the Name as the user types,
      // but a manual edit to the slug pins it. Implemented via a
      // `_slugTouchedByUser` latch that flips once on first slug
      // edit and never resets.
      expect(src, contains('bool _slugTouchedByUser = false'));
      expect(src, contains('if (!_slugTouchedByUser)'));
      expect(src, contains('_autoSlugFromName('));
    });

    test('_autoSlugFromName lowercases + hyphenates + trims edge hyphens', () {
      // Slugifier rules mirror the backend slug regex
      // (a-z0-9, hyphens, 3..64 chars, no leading/trailing hyphen).
      // Keep the regex pins so a refactor doesn't change shape.
      expect(src, contains("toLowerCase()"));
      expect(src, contains(r"replaceAll(RegExp(r'[^a-z0-9]+'), '-')"));
      expect(src, contains(r"replaceAll(RegExp(r'^-+|-+$'), '')"));
    });

    test('name validation mirrors backend 1..50 char window', () {
      // Backend rejects empty + >50 with structured reasons; the
      // sheet enforces both before submit so users never round-trip
      // a guaranteed-reject request.
      expect(src, contains('_licenseOrgNameMinLength = 1'));
      expect(src, contains('_licenseOrgNameMaxLength = 50'));
      expect(src, contains('String? _validateLicenseOrgName'));
    });

    test('_isInputValid gates the submit CTA on BOTH name and slug', () {
      // Bug guard: validating only the slug (the pre-mandate
      // behavior) lets the CTA enable with an empty Name and the
      // server rejects post-tap. Must gate on both.
      expect(
        src,
        contains('_validateLicenseOrgId(_controller.text) != null &&'),
      );
      expect(
        src,
        contains('_validateLicenseOrgName(_nameController.text) != null'),
      );
    });

    test('_submit validates name first, then slug', () {
      // Submit order matters for the error banner: if the user
      // leaves name empty AND types an invalid slug, the name
      // error fires first (the field above), so the eye lands on
      // the correct field. Pin the order.
      final submitIdx = src.indexOf('Future<void> _submit() async {');
      expect(submitIdx, greaterThan(-1));
      final body = src.substring(submitIdx, submitIdx + 800);
      final nameIdx = body.indexOf('_validateLicenseOrgName(_nameController');
      final slugIdx = body.indexOf('_validateLicenseOrgId(_controller');
      expect(nameIdx, greaterThan(-1));
      expect(slugIdx, greaterThan(nameIdx));
    });

    test('createCheckout call carries licenseOrgName', () {
      // The whole point of the slice: the buy sheet's
      // createCheckout payload must pass the name through so the
      // webhook can write a non-empty name to the org doc.
      expect(src, contains('licenseOrgName: name,'));
    });

    test('server name-rejection reasons map to user copy', () {
      // The backend may reject with any of these structured
      // reasons on a name validation failure; map each one to a
      // localized message so users see actionable copy, not the
      // generic fallback.
      expect(src, contains("case 'license-org-name-required':"));
      expect(src, contains("case 'license-org-name-empty':"));
      expect(src, contains("case 'license-org-name-malformed':"));
      expect(src, contains("case 'license-org-name-too-long':"));
      expect(src, contains('orgCheckoutNameRequired'));
      expect(src, contains('orgCheckoutNameTooLong'));
    });

    test('Name TextField renders BEFORE the Group ID TextField in build', () {
      // Visual layout invariant: Name above Group ID. A future
      // refactor that reorders these would put the auto-derived
      // slug field above the source-of-truth Name, which is
      // confusing.
      final buildIdx = src.indexOf('Widget build(BuildContext context) {');
      expect(buildIdx, greaterThan(-1));
      final body = src.substring(buildIdx, buildIdx + 3500);
      final nameFieldIdx = body.indexOf('controller: _nameController');
      final slugFieldIdx = body.indexOf('controller: _controller');
      expect(nameFieldIdx, greaterThan(-1));
      expect(slugFieldIdx, greaterThan(nameFieldIdx));
    });
  });
}
