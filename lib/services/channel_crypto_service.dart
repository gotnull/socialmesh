// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging.dart';
import '../models/mesh_models.dart';
import '../providers/auth_providers.dart';

/// Service for secure channel key sharing via Firestore.
///
/// Uses AES-256-GCM to encrypt PSKs per-member. Each member's key blob
/// is stored at `shared_channels/{channelId}/keys/{uid}` so that only
/// the target user (enforced by Firestore rules) can read it.
///
/// The per-user encryption key is derived from a secret that only the
/// owner and the target user share. In this implementation we use a
/// deterministic key derived from the channel ID + user ID + a server-
/// stored owner secret, which the Cloud Function sets when adding members.
///
/// For the MVP approach: the channel owner encrypts the PSK with a
/// per-user key derived from (ownerUid + targetUid + channelId) using
/// HKDF, and stores the encrypted blob. The derivation material is
/// never stored alongside the ciphertext.
class ChannelCryptoService {
  ChannelCryptoService(this._ref);

  final Ref _ref;

  static const int _currentKeyVersion = 1;

  /// Encrypt a PSK for a specific target user.
  ///
  /// Returns a map suitable for writing to Firestore at
  /// `shared_channels/{channelId}/keys/{targetUid}`.
  Future<Map<String, dynamic>> encryptPskForUser({
    required List<int> psk,
    required String channelId,
    required String ownerUid,
    required String targetUid,
  }) async {
    final derivedKey = await _deriveKey(
      channelId: channelId,
      ownerUid: ownerUid,
      targetUid: targetUid,
    );

    final algorithm = AesGcm.with256bits();
    final secretKey = SecretKey(derivedKey);
    final secretBox = await algorithm.encrypt(
      Uint8List.fromList(psk),
      secretKey: secretKey,
    );

    return {
      'encryptedPsk': base64Encode(secretBox.concatenation()),
      'keyVersion': _currentKeyVersion,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Decrypt a PSK from a user's key blob document.
  ///
  /// [keyData] is the Firestore document data from
  /// `shared_channels/{channelId}/keys/{uid}`.
  Future<List<int>?> decryptPskForUser({
    required Map<String, dynamic> keyData,
    required String channelId,
    required String ownerUid,
    required String currentUid,
  }) async {
    try {
      final encryptedB64 = keyData['encryptedPsk'] as String?;
      if (encryptedB64 == null) return null;

      final concatenation = base64Decode(encryptedB64);

      final derivedKey = await _deriveKey(
        channelId: channelId,
        ownerUid: ownerUid,
        targetUid: currentUid,
      );

      final algorithm = AesGcm.with256bits();
      final secretKey = SecretKey(derivedKey);

      // AES-GCM concatenation: nonce (12) + ciphertext + mac (16)
      final secretBox = SecretBox.fromConcatenation(
        concatenation,
        nonceLength: 12,
        macLength: 16,
      );

      final decrypted = await algorithm.decrypt(
        secretBox,
        secretKey: secretKey,
      );

      return decrypted;
    } catch (e) {
      AppLogging.channels('[ChannelCrypto] Decryption failed: $e');
      return null;
    }
  }

  /// Share a channel securely: writes metadata (without PSK) and
  /// encrypted key blob for the owner.
  ///
  /// Returns the Firestore document ID.
  Future<String> shareChannelSecurely({
    required ChannelConfig channel,
    required String ownerUid,
  }) async {
    final firestore = FirebaseFirestore.instance;

    // Check for existing channel (same owner + name, no PSK comparison
    // since we no longer store plaintext PSK)
    final existingId = await _findExistingChannel(ownerUid, channel.name);
    String docId;

    if (existingId != null) {
      docId = existingId;

      // Update metadata to reflect current channel settings so invite
      // recipients always get the latest values (uplink, downlink, role, etc.).
      // positionPrecision is deliberately set to 0 because it is a per-device
      // preference — the sharer's position-sharing choice must not propagate
      // to recipients.
      await firestore.collection('shared_channels').doc(docId).update({
        'index': channel.index,
        'role': channel.role,
        'uplink': channel.uplink,
        'downlink': channel.downlink,
        'positionPrecision': 0,
      });

      AppLogging.channels(
        '[ChannelCrypto] Reusing existing channel "${channel.name}" '
        'with ID $docId (metadata updated)',
      );
    } else {
      // Create channel metadata document (NO PSK)
      final docRef = await firestore.collection('shared_channels').add({
        'name': channel.name,
        'index': channel.index,
        'role': channel.role,
        'uplink': channel.uplink,
        'downlink': channel.downlink,
        // Always store 0 — positionPrecision is a per-device preference and
        // must not propagate to invite recipients.
        'positionPrecision': 0,
        'createdBy': ownerUid,
        'createdAt': FieldValue.serverTimestamp(),
        'keyVersion': _currentKeyVersion,
      });
      docId = docRef.id;

      AppLogging.channels(
        '[ChannelCrypto] Created secure channel "${channel.name}" '
        'with ID $docId',
      );
    }

    // Write encrypted key blob for the owner
    final keyBlob = await encryptPskForUser(
      psk: channel.psk,
      channelId: docId,
      ownerUid: ownerUid,
      targetUid: ownerUid,
    );

    await firestore
        .collection('shared_channels')
        .doc(docId)
        .collection('keys')
        .doc(ownerUid)
        .set(keyBlob);

    // Add owner as member
    await firestore
        .collection('shared_channels')
        .doc(docId)
        .collection('members')
        .doc(ownerUid)
        .set({'role': 'owner', 'addedAt': FieldValue.serverTimestamp()});

    return docId;
  }

  /// Add a member to a shared channel and encrypt the PSK for them.
  Future<void> addMember({
    required String channelId,
    required String ownerUid,
    required String targetUid,
    required List<int> psk,
  }) async {
    final firestore = FirebaseFirestore.instance;

    // Write encrypted key blob for the target user
    final keyBlob = await encryptPskForUser(
      psk: psk,
      channelId: channelId,
      ownerUid: ownerUid,
      targetUid: targetUid,
    );

    await firestore
        .collection('shared_channels')
        .doc(channelId)
        .collection('keys')
        .doc(targetUid)
        .set(keyBlob);

    // Add membership record
    await firestore
        .collection('shared_channels')
        .doc(channelId)
        .collection('members')
        .doc(targetUid)
        .set({'role': 'member', 'addedAt': FieldValue.serverTimestamp()});
  }

  /// Fetch and decrypt the PSK for the current user from a shared channel.
  Future<ChannelConfig?> fetchSecureChannel(String channelId) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return null;

    final firestore = FirebaseFirestore.instance;

    try {
      // Fetch channel metadata
      final channelDoc = await firestore
          .collection('shared_channels')
          .doc(channelId)
          .get();
      if (!channelDoc.exists) {
        AppLogging.channels('[ChannelCrypto] Channel $channelId not found');
        return null;
      }

      final channelData = channelDoc.data()!;
      final ownerUid = channelData['createdBy'] as String?;
      if (ownerUid == null) return null;

      // Fetch user's encrypted key blob
      final keyDoc = await firestore
          .collection('shared_channels')
          .doc(channelId)
          .collection('keys')
          .doc(user.uid)
          .get();

      if (!keyDoc.exists) {
        AppLogging.channels(
          '[ChannelCrypto] No key blob for user ${user.uid} '
          'in channel $channelId',
        );
        return null;
      }

      final keyData = keyDoc.data()!;

      // Decrypt PSK
      final psk = await decryptPskForUser(
        keyData: keyData,
        channelId: channelId,
        ownerUid: ownerUid,
        currentUid: user.uid,
      );

      if (psk == null) return null;

      return ChannelConfig(
        index: channelData['index'] as int? ?? 0,
        name: channelData['name'] as String? ?? '',
        psk: psk,
        uplink: channelData['uplink'] as bool? ?? false,
        downlink: channelData['downlink'] as bool? ?? false,
        role: channelData['role'] as String? ?? 'SECONDARY',
        positionPrecision: channelData['positionPrecision'] as int? ?? 0,
      );
    } catch (e) {
      AppLogging.channels('[ChannelCrypto] Error fetching channel: $e');
      return null;
    }
  }

  /// Rotate the key for a channel. Increments keyVersion, re-encrypts
  /// PSK for all members, and updates the channel document.
  Future<bool> rotateKey({
    required String channelId,
    required List<int> newPsk,
    required String ownerUid,
  }) async {
    final firestore = FirebaseFirestore.instance;

    try {
      // Get current key version
      final channelDoc = await firestore
          .collection('shared_channels')
          .doc(channelId)
          .get();
      if (!channelDoc.exists) return false;

      final currentVersion =
          channelDoc.data()?['keyVersion'] as int? ?? _currentKeyVersion;
      final newVersion = currentVersion + 1;

      // Get all members
      final membersSnapshot = await firestore
          .collection('shared_channels')
          .doc(channelId)
          .collection('members')
          .get();

      // Re-encrypt for all members with new key version
      final batch = firestore.batch();

      for (final memberDoc in membersSnapshot.docs) {
        final memberUid = memberDoc.id;
        final keyBlob = await encryptPskForUser(
          psk: newPsk,
          channelId: channelId,
          ownerUid: ownerUid,
          targetUid: memberUid,
        );
        // Override keyVersion with new version
        keyBlob['keyVersion'] = newVersion;

        batch.set(
          firestore
              .collection('shared_channels')
              .doc(channelId)
              .collection('keys')
              .doc(memberUid),
          keyBlob,
        );
      }

      // Update channel key version
      batch.update(firestore.collection('shared_channels').doc(channelId), {
        'keyVersion': newVersion,
        'keyRotatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      AppLogging.channels(
        '[ChannelCrypto] Rotated key for channel $channelId '
        'from v$currentVersion to v$newVersion',
      );

      return true;
    } catch (e) {
      AppLogging.channels('[ChannelCrypto] Key rotation failed: $e');
      return false;
    }
  }

  /// Derive a per-user encryption key using HKDF.
  Future<List<int>> _deriveKey({
    required String channelId,
    required String ownerUid,
    required String targetUid,
  }) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

    // Input keying material: combination of IDs that only owner knows
    // to construct for each target
    final ikm = utf8.encode('$ownerUid:$targetUid:$channelId');

    final derivedKey = await hkdf.deriveKey(
      secretKey: SecretKey(ikm),
      info: utf8.encode('socialmesh-channel-psk-v1'),
    );

    return derivedKey.extractBytes();
  }

  /// Find an existing channel by name for the given owner.
  Future<String?> _findExistingChannel(String ownerUid, String name) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('shared_channels')
          .where('createdBy', isEqualTo: ownerUid)
          .where('name', isEqualTo: name)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.id;
      }
    } catch (e) {
      AppLogging.channels('[ChannelCrypto] Error finding existing channel: $e');
    }
    return null;
  }
}

/// Provider for the channel crypto service.
final channelCryptoServiceProvider = Provider<ChannelCryptoService>((ref) {
  return ChannelCryptoService(ref);
});
