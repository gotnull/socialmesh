// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D46-A: preview struct surfaced by the contact-import confirmation
// sheet between paste/parse and the firmware-bound commit.
//
// Two variants discriminated by the `format` enum:
//   - `modern`: parsed from a canonical `meshcore://<hex>` URL. Carries
//     the raw 135..147-byte contact frame so `commit` can re-serialize
//     verbatim via `CMD_IMPORT_CONTACT 0x12`.
//   - `legacy`: parsed from the SocialMesh-only `<pubkeyhex>:<name>`
//     stopgap format. Carries pubkey + name only; commit re-routes
//     through `CMD_ADD_UPDATE_CONTACT 0x09` (the D29 path) since the
//     firmware import RPC needs the full canonical frame.

import 'dart:typed_data';

import 'meshcore_contact.dart';

enum MeshCoreContactImportFormat {
  /// Canonical `meshcore://` URL — full contact frame round-tripped
  /// from `CMD_EXPORT_CONTACT`.
  modern,

  /// Legacy `<pubkeyhex>:<name>` — pre-D46-A SocialMesh stopgap.
  legacy,
}

class MeshCoreContactImportPreview {
  /// Wire-format provenance. UI surfaces this so the user knows
  /// whether the import carries full fidelity (path, GPS, type) or
  /// is a name-only stub.
  final MeshCoreContactImportFormat format;

  /// Parsed contact rendered into our local model. For `modern` this
  /// is `parseContact`'s `MeshCoreContactInfo` rolled into a
  /// [MeshCoreContact]; for `legacy` it's a stub with
  /// `pathLength = -1` and `type = chat`.
  final MeshCoreContact contact;

  /// Canonical 8-char fingerprint of the contact's pubkey, suitable
  /// for the confirmation sheet. Never the full 64-char hex.
  final String pubKeyFingerprint8;

  /// Raw 135..147-byte contact frame from `MeshCoreContactUrl.decode`.
  /// Non-null only for [MeshCoreContactImportFormat.modern]; null for
  /// legacy previews because the legacy text-form cannot reconstruct
  /// a wire-canonical frame.
  final Uint8List? frameBytes;

  const MeshCoreContactImportPreview({
    required this.format,
    required this.contact,
    required this.pubKeyFingerprint8,
    this.frameBytes,
  });

  /// True iff `commit` can use `CMD_IMPORT_CONTACT` (full-frame
  /// round-trip). False for legacy previews which route through
  /// `CMD_ADD_UPDATE_CONTACT`.
  bool get isFullFrame =>
      format == MeshCoreContactImportFormat.modern && frameBytes != null;
}
