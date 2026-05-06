// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart' as pc;

import '../../core/logging.dart';

/// Manages on-device TLS certificate authority and derived certificates
/// for the mesh-native TAK server (Sprint 016).
///
/// Generates a self-signed RSA-2048 root CA on first launch, derives
/// client certificates from it, and stores all key material in platform
/// secure storage (Keychain on iOS, Keystore on Android).
class TakCertificateManager {
  static const _caKeyKey = 'tak_ca_key_pem';
  static const _caCertKey = 'tak_ca_cert_pem';
  static const _serverKeyKey = 'tak_server_key_pem';
  static const _serverCertKey = 'tak_server_cert_pem';

  /// Certificate validity period in days.
  static const int certValidityDays = 365;

  /// Renewal threshold: regenerate when expiry is within this many days.
  static const int renewalThresholdDays = 30;

  final FlutterSecureStorage _storage;

  String? _cachedCaPem;
  String? _cachedCaKeyPem;
  String? _cachedServerCertPem;
  String? _cachedServerKeyPem;
  DateTime? _cachedCaExpiry;

  TakCertificateManager({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Initialises the certificate manager, generating a root CA if none exists.
  Future<void> initialize() async {
    AppLogging.tak('Certificate manager initializing');
    final existingCert = await _storage.read(key: _caCertKey);
    if (existingCert == null) {
      AppLogging.tak('No CA found — generating root CA');
      await _generateRootCa();
    } else {
      AppLogging.tak('Found existing CA in secure storage');
      _cachedCaPem = existingCert;
      _cachedCaKeyPem = await _storage.read(key: _caKeyKey);
      _cachedServerCertPem = await _storage.read(key: _serverCertKey);
      _cachedServerKeyPem = await _storage.read(key: _serverKeyKey);
    }
    AppLogging.tak('Certificate manager initialized');
  }

  /// Returns the PEM-encoded CA certificate for data package export.
  Future<String> getCaCertificatePem() async {
    if (_cachedCaPem != null) return _cachedCaPem!;
    final pem = await _storage.read(key: _caCertKey);
    if (pem == null) throw StateError('CA not initialized — call initialize()');
    return _cachedCaPem = pem;
  }

  /// Returns the PEM-encoded CA private key.
  Future<String> getCaPrivateKeyPem() async {
    if (_cachedCaKeyPem != null) return _cachedCaKeyPem!;
    final pem = await _storage.read(key: _caKeyKey);
    if (pem == null) throw StateError('CA key not initialized');
    return _cachedCaKeyPem = pem;
  }

  /// Returns the server certificate and private key in PEM format.
  Future<({String certPem, String keyPem})> getServerCertificateAndKey() async {
    final cert =
        _cachedServerCertPem ?? await _storage.read(key: _serverCertKey);
    final key = _cachedServerKeyPem ?? await _storage.read(key: _serverKeyKey);
    if (cert == null || key == null) {
      throw StateError('Server cert not initialized — call initialize()');
    }
    _cachedServerCertPem = cert;
    _cachedServerKeyPem = key;
    return (certPem: cert, keyPem: key);
  }

  /// Generates a client certificate signed by the CA with [callsign] as CN.
  Future<({String certPem, String keyPem})> generateClientCertificate(
    String callsign,
  ) async {
    AppLogging.tak('Generating client certificate for callsign=$callsign');
    final caKeyPem = await getCaPrivateKeyPem();
    final keyPair = _generateRsaKeyPair();
    final serial = Random.secure().nextInt(0x7FFFFFFF).abs() + 3;
    final certPem = _buildCert(
      subjectCn: callsign,
      issuerCn: 'SocialMesh TAK CA',
      publicKey: keyPair.publicKey,
      serial: serial,
      notBefore: DateTime.now().toUtc(),
      notAfter: DateTime.now().toUtc().add(
        const Duration(days: certValidityDays),
      ),
      isCA: false,
      signingKey: _loadPrivateKeyFromPem(caKeyPem),
    );
    final keyPem = _encodePrivateKeyPem(keyPair.privateKey);
    AppLogging.tak(
      'Client certificate generated: CN=$callsign, serial=${serial.toRadixString(16)}',
    );
    return (certPem: certPem, keyPem: keyPem);
  }

  /// Checks expiry and regenerates if within [renewalThresholdDays] days.
  Future<void> checkAndRenew() async {
    final expiry =
        _cachedCaExpiry ??
        DateTime.now().toUtc().add(const Duration(days: certValidityDays));
    final renewBefore = expiry.subtract(
      const Duration(days: renewalThresholdDays),
    );
    if (DateTime.now().isAfter(renewBefore)) {
      AppLogging.tak(
        'CA expiry within $renewalThresholdDays days — regenerating',
      );
      await _generateRootCa();
    }
  }

  /// Clears all stored certificates (use for reset / testing).
  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _caKeyKey),
      _storage.delete(key: _caCertKey),
      _storage.delete(key: _serverKeyKey),
      _storage.delete(key: _serverCertKey),
    ]);
    _cachedCaPem = null;
    _cachedCaKeyPem = null;
    _cachedServerCertPem = null;
    _cachedServerKeyPem = null;
    _cachedCaExpiry = null;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<void> _generateRootCa() async {
    final now = DateTime.now().toUtc();
    final expiry = now.add(const Duration(days: certValidityDays));
    final caKeyPair = _generateRsaKeyPair();
    final caPrivKey = caKeyPair.privateKey;
    final caPubKey = caKeyPair.publicKey;
    final caKeyPem = _encodePrivateKeyPem(caPrivKey);
    final caCertPem = _buildCert(
      subjectCn: 'SocialMesh TAK CA',
      issuerCn: 'SocialMesh TAK CA',
      publicKey: caPubKey,
      serial: 1,
      notBefore: now,
      notAfter: expiry,
      isCA: true,
      signingKey: caPrivKey, // self-signed
    );
    // Generate server cert signed by CA
    final serverKeyPair = _generateRsaKeyPair();
    final serverPrivKey = serverKeyPair.privateKey;
    final serverPubKey = serverKeyPair.publicKey;
    final serverKeyPem = _encodePrivateKeyPem(serverPrivKey);
    final serverCertPem = _buildCert(
      subjectCn: 'SocialMesh TAK Server',
      issuerCn: 'SocialMesh TAK CA',
      publicKey: serverPubKey,
      serial: 2,
      notBefore: now,
      notAfter: expiry,
      isCA: false,
      signingKey: caPrivKey,
    );
    await Future.wait([
      _storage.write(key: _caCertKey, value: caCertPem),
      _storage.write(key: _caKeyKey, value: caKeyPem),
      _storage.write(key: _serverCertKey, value: serverCertPem),
      _storage.write(key: _serverKeyKey, value: serverKeyPem),
    ]);
    _cachedCaPem = caCertPem;
    _cachedCaKeyPem = caKeyPem;
    _cachedServerCertPem = serverCertPem;
    _cachedServerKeyPem = serverKeyPem;
    _cachedCaExpiry = expiry;
    AppLogging.tak(
      'Root CA generated: CN=SocialMesh TAK CA, expires=${expiry.toIso8601String()}',
    );
  }

  static pc.AsymmetricKeyPair<pc.RSAPublicKey, pc.RSAPrivateKey>
  _generateRsaKeyPair() {
    final secureRandom = pc.FortunaRandom();
    final seedSource = Random.secure();
    final seeds = List<int>.generate(32, (_) => seedSource.nextInt(256));
    secureRandom.seed(pc.KeyParameter(Uint8List.fromList(seeds)));

    final keyGen = pc.RSAKeyGenerator()
      ..init(
        pc.ParametersWithRandom(
          pc.RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
          secureRandom,
        ),
      );
    final pair = keyGen.generateKeyPair();
    return pc.AsymmetricKeyPair(pair.publicKey, pair.privateKey);
  }

  String _buildCert({
    required String subjectCn,
    required String issuerCn,
    required pc.RSAPublicKey publicKey,
    required int serial,
    required DateTime notBefore,
    required DateTime notAfter,
    required bool isCA,
    required pc.RSAPrivateKey signingKey,
  }) {
    final nBytes = _bigIntToUint8List(publicKey.modulus!);
    final eBytes = _bigIntToUint8List(publicKey.publicExponent!);
    final tbs = _DerEncoder.tbsCertificate(
      subjectCn: subjectCn,
      issuerCn: issuerCn,
      nBytes: nBytes,
      eBytes: eBytes,
      serial: serial,
      notBefore: notBefore,
      notAfter: notAfter,
      isCA: isCA,
    );
    // Sign the TBS with the issuer key
    final signer = pc.RSASigner(pc.SHA256Digest(), '0609608648016503040201');
    signer.init(true, pc.PrivateKeyParameter<pc.RSAPrivateKey>(signingKey));
    final sig = signer.generateSignature(tbs);
    final certDer = _DerEncoder.certificate(tbs, Uint8List.fromList(sig.bytes));
    return _derToPem(certDer, 'CERTIFICATE');
  }

  /// Loads an RSA private key from PKCS#8 PEM.
  static pc.RSAPrivateKey _loadPrivateKeyFromPem(String keyPem) {
    final der = _pemToDer(keyPem, 'PRIVATE KEY');
    return _DerDecoder.parseRsaPrivateKeyPkcs8(der);
  }

  static String _encodePrivateKeyPem(pc.RSAPrivateKey key) {
    final der = _DerEncoder.pkcs8PrivateKey(key);
    return _derToPem(der, 'PRIVATE KEY');
  }

  static Uint8List _bigIntToUint8List(BigInt bigInt) {
    final hexStr = bigInt.toRadixString(16);
    final padded = hexStr.length.isOdd ? '0$hexStr' : hexStr;
    final result = Uint8List(padded.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] = int.parse(padded.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }

  static String _derToPem(Uint8List der, String label) {
    final encoded = base64.encode(der);
    final buf = StringBuffer('-----BEGIN $label-----\n');
    for (var i = 0; i < encoded.length; i += 64) {
      buf.writeln(
        encoded.substring(
          i,
          (i + 64) > encoded.length ? encoded.length : i + 64,
        ),
      );
    }
    buf.write('-----END $label-----');
    return buf.toString();
  }

  static Uint8List _pemToDer(String pem, String label) {
    final lines = pem
        .split('\n')
        .where(
          (l) =>
              l.isNotEmpty &&
              !l.startsWith('-----BEGIN') &&
              !l.startsWith('-----END'),
        )
        .join();
    return Uint8List.fromList(base64.decode(lines));
  }
}

// =============================================================================
// DER encoder — minimal X.509 subset
// =============================================================================

abstract final class _DerEncoder {
  // OIDs
  static const _oidRsa = [0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01];
  static const _oidSha256Rsa = [
    0x2A,
    0x86,
    0x48,
    0x86,
    0xF7,
    0x0D,
    0x01,
    0x01,
    0x0B,
  ];
  static const _oidCn = [0x55, 0x04, 0x03];
  static const _oidBasicConstraints = [0x55, 0x1D, 0x13];

  static Uint8List tbsCertificate({
    required String subjectCn,
    required String issuerCn,
    required Uint8List nBytes,
    required Uint8List eBytes,
    required int serial,
    required DateTime notBefore,
    required DateTime notAfter,
    required bool isCA,
  }) {
    final parts = <Uint8List>[
      // version [0] EXPLICIT v3
      _tagged(0xA0, _integer([0x02])),
      // serial
      _integer(_bigIntToBytes(serial)),
      // signatureAlgorithm sha256WithRSAEncryption
      _sha256RsaAlgorithm(),
      // issuer
      _rdnSequence(issuerCn),
      // validity
      _sequence([_utcTime(notBefore), _utcTime(notAfter)]),
      // subject
      _rdnSequence(subjectCn),
      // subjectPublicKeyInfo
      _spki(nBytes, eBytes),
    ];
    if (isCA) {
      parts.add(_tagged(0xA3, _basicConstraintsCa()));
    }
    return _sequence(parts);
  }

  static Uint8List certificate(Uint8List tbs, Uint8List signature) {
    return _sequence([tbs, _sha256RsaAlgorithm(), _bitStringRaw(signature)]);
  }

  static Uint8List pkcs8PrivateKey(pc.RSAPrivateKey key) {
    final n = _bigIntToUint8List(key.modulus!);
    final e = _bigIntToUint8List(key.publicExponent!);
    final d = _bigIntToUint8List(key.privateExponent!);
    final p = _bigIntToUint8List(key.p!);
    final q = _bigIntToUint8List(key.q!);
    final dp = _bigIntToUint8List(key.privateExponent! % (key.p! - BigInt.one));
    final dq = _bigIntToUint8List(key.privateExponent! % (key.q! - BigInt.one));
    final qi = _bigIntToUint8List(key.q!.modInverse(key.p!));
    final rsaKey = _sequence([
      _integer([0x00]), // version
      _integer(_prependZero(n)),
      _integer(_prependZero(e)),
      _integer(_prependZero(d)),
      _integer(_prependZero(p)),
      _integer(_prependZero(q)),
      _integer(_prependZero(dp)),
      _integer(_prependZero(dq)),
      _integer(_prependZero(qi)),
    ]);
    return _sequence([
      _integer([0x00]),
      _sequence([_oid(_oidRsa), _null()]),
      _octetString(rsaKey),
    ]);
  }

  static Uint8List _sha256RsaAlgorithm() =>
      _sequence([_oid(_oidSha256Rsa), _null()]);

  static Uint8List _rdnSequence(String cn) => _sequence([
    _set([
      _sequence([_oid(_oidCn), _utf8String(cn)]),
    ]),
  ]);

  static Uint8List _spki(Uint8List n, Uint8List e) {
    final innerKey = _sequence([_integer(_prependZero(n)), _integer(e)]);
    return _sequence([
      _sequence([_oid(_oidRsa), _null()]),
      _bitStringRaw(innerKey),
    ]);
  }

  static Uint8List _basicConstraintsCa() {
    final inner = _sequence([
      _sequence([
        _oid(_oidBasicConstraints),
        _bool(true),
        _octetString(_sequence([_bool(true)])),
      ]),
    ]);
    return inner;
  }

  // ---------- Primitive encoders ----------

  static Uint8List _tlv(int tag, Uint8List value) {
    final len = _encodeLength(value.length);
    final out = Uint8List(1 + len.length + value.length);
    out[0] = tag;
    out.setRange(1, 1 + len.length, len);
    out.setRange(1 + len.length, out.length, value);
    return out;
  }

  static Uint8List _sequence(List<Uint8List> parts) =>
      _tlv(0x30, _concat(parts));

  static Uint8List _set(List<Uint8List> parts) => _tlv(0x31, _concat(parts));

  static Uint8List _integer(List<int> bytes) =>
      _tlv(0x02, Uint8List.fromList(bytes));

  static Uint8List _oid(List<int> bytes) =>
      _tlv(0x06, Uint8List.fromList(bytes));

  static Uint8List _null() => Uint8List.fromList([0x05, 0x00]);

  static Uint8List _utf8String(String s) =>
      _tlv(0x0C, Uint8List.fromList(utf8.encode(s)));

  static Uint8List _bool(bool b) =>
      _tlv(0x01, Uint8List.fromList([b ? 0xFF : 0x00]));

  static Uint8List _bitStringRaw(Uint8List data) {
    final val = Uint8List(data.length + 1);
    val[0] = 0x00; // no unused bits
    val.setRange(1, val.length, data);
    return _tlv(0x03, val);
  }

  static Uint8List _octetString(Uint8List inner) => _tlv(0x04, inner);

  static Uint8List _utcTime(DateTime dt) {
    final s = dt.toUtc();
    final str =
        '${(s.year % 100).toString().padLeft(2, "0")}'
        '${s.month.toString().padLeft(2, "0")}'
        '${s.day.toString().padLeft(2, "0")}'
        '${s.hour.toString().padLeft(2, "0")}'
        '${s.minute.toString().padLeft(2, "0")}'
        '${s.second.toString().padLeft(2, "0")}Z';
    return _tlv(0x17, Uint8List.fromList(str.codeUnits));
  }

  static Uint8List _tagged(int tag, Uint8List content) => _tlv(tag, content);

  static Uint8List _concat(List<Uint8List> parts) {
    final total = parts.fold(0, (sum, p) => sum + p.length);
    final out = Uint8List(total);
    var offset = 0;
    for (final p in parts) {
      out.setRange(offset, offset + p.length, p);
      offset += p.length;
    }
    return out;
  }

  static Uint8List _encodeLength(int length) {
    if (length < 128) return Uint8List.fromList([length]);
    if (length < 256) return Uint8List.fromList([0x81, length]);
    return Uint8List.fromList([0x82, (length >> 8) & 0xFF, length & 0xFF]);
  }

  static Uint8List _bigIntToBytes(int value) {
    if (value == 0) return Uint8List.fromList([0x00]);
    final result = <int>[];
    var v = value;
    while (v > 0) {
      result.insert(0, v & 0xFF);
      v >>= 8;
    }
    if (result[0] & 0x80 != 0) result.insert(0, 0x00);
    return Uint8List.fromList(result);
  }

  static Uint8List _bigIntToUint8List(BigInt bigInt) {
    final hexStr = bigInt.toRadixString(16);
    final padded = hexStr.length.isOdd ? '0$hexStr' : hexStr;
    final result = Uint8List(padded.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] = int.parse(padded.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }

  static Uint8List _prependZero(Uint8List b) {
    if (b.isEmpty || b[0] & 0x80 != 0) {
      return Uint8List.fromList([0x00, ...b]);
    }
    return b;
  }
}

// =============================================================================
// DER decoder — PKCS#8 RSA private key parser
// =============================================================================

abstract final class _DerDecoder {
  /// Parses a PKCS#8-encoded RSA private key DER into [pc.RSAPrivateKey].
  static pc.RSAPrivateKey parseRsaPrivateKeyPkcs8(Uint8List der) {
    // PKCS#8: SEQUENCE { INTEGER(0), SEQUENCE{OID,...}, OCTET STRING { rsaKey } }
    var offset = _skipTlvHeader(der, 0, 0x30); // outer SEQUENCE

    // Skip version INTEGER
    offset = _skipTlv(der, offset);

    // Skip algorithmIdentifier SEQUENCE
    offset = _skipTlv(der, offset);

    // Enter OCTET STRING containing RSA private key SEQUENCE
    offset = _skipTlvHeader(der, offset, 0x04);
    return _parseRsaPrivateKey(der, offset);
  }

  /// Skips an entire TLV element, returning the offset after it.
  static int _skipTlv(Uint8List der, int offset) {
    final lenSize = _lengthFieldSize(der, offset + 1);
    final length = _tlvLength(der, offset + 1);
    return offset + 1 + lenSize + length;
  }

  static pc.RSAPrivateKey _parseRsaPrivateKey(Uint8List der, int start) {
    var offset = _skipTlvHeader(der, start, 0x30);
    BigInt readBigInt() {
      final tag = der[offset];
      assert(
        tag == 0x02,
        'Expected INTEGER tag 0x02, got 0x${tag.toRadixString(16)}',
      );
      final lenSize = _lengthFieldSize(der, offset + 1);
      final length = _tlvLength(der, offset + 1);
      final value = der.sublist(
        offset + 1 + lenSize,
        offset + 1 + lenSize + length,
      );
      offset += 1 + lenSize + length;
      // Convert bytes to BigInt
      var result = BigInt.zero;
      for (final b in value) {
        result = (result << 8) | BigInt.from(b);
      }
      return result;
    }

    readBigInt(); // version (0)
    final n = readBigInt();
    readBigInt(); // e (public exponent — derived by RSAPrivateKey)
    final d = readBigInt();
    final p = readBigInt();
    final q = readBigInt();
    readBigInt(); // dp — not needed for constructor
    readBigInt(); // dq
    readBigInt(); // qi
    return pc.RSAPrivateKey(n, d, p, q);
  }

  static int _skipTlvHeader(Uint8List der, int offset, int expectedTag) {
    assert(der[offset] == expectedTag);
    return offset + 1 + _lengthFieldSize(der, offset + 1);
  }

  static int _lengthFieldSize(Uint8List der, int offset) {
    final b = der[offset];
    if (b < 0x80) return 1;
    if (b == 0x81) return 2;
    return 3;
  }

  static int _tlvLength(Uint8List der, int offset) {
    final b = der[offset];
    if (b < 0x80) return b;
    if (b == 0x81) return der[offset + 1];
    return (der[offset + 1] << 8) | der[offset + 2];
  }
}
