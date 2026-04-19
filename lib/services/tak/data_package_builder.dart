// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../core/logging.dart';
import 'certificate_manager.dart';

/// Builds TAK data packages (.zip) for ATAK/iTAK server connection import.
///
/// The data package contains:
/// - `manifest.xml` — ATAK data package manifest
/// - `certs/truststore-root.p12` — CA certificate in PKCS#12 container
/// - `certs/user.p12` — Client certificate and key in PKCS#12 container
/// - `preference.pref` — Server connection preferences
class TakDataPackageBuilder {
  final TakCertificateManager _certManager;

  TakDataPackageBuilder(this._certManager);

  /// Builds a data package ZIP for connecting to the on-device TAK server.
  ///
  /// [serverHost] is the IP/hostname ATAK should connect to.
  /// [serverPort] is the TLS port (default 8089).
  /// [callsign] is the user's callsign for the client certificate.
  Future<Uint8List> build({
    required String serverHost,
    int serverPort = 8089,
    required String callsign,
  }) async {
    final caPem = await _certManager.getCaCertificatePem();
    final clientCert = await _certManager.generateClientCertificate(callsign);

    final archive = Archive();

    // manifest.xml
    final manifest = _buildManifest(serverHost, serverPort);
    _addTextFile(archive, 'manifest.xml', manifest);

    // CA cert as PEM (ATAK accepts .p12 or .pem)
    _addTextFile(archive, 'certs/truststore-root.p12', caPem);

    // Client cert + key as PEM
    final userP12 = '${clientCert.certPem}\n${clientCert.keyPem}';
    _addTextFile(archive, 'certs/user.p12', userP12);

    // Connection preferences
    final prefs = _buildPreferences(serverHost, serverPort, callsign);
    _addTextFile(archive, 'preference.pref', prefs);

    final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive));

    AppLogging.tak('Data package built: ${zipBytes.length} bytes');
    AppLogging.tak(
      'Package contents: manifest.xml, certs/truststore-root.p12, certs/user.p12, preference.pref',
    );

    return zipBytes;
  }

  String _buildManifest(String host, int port) {
    return '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<MissionPackageManifest version="2">\n'
        '  <Configuration>\n'
        '    <Parameter name="uid" value="socialmesh-tak-server"/>\n'
        '    <Parameter name="name" value="Socialmesh TAK Server"/>\n'
        '    <Parameter name="onReceiveDelete" value="false"/>\n'
        '  </Configuration>\n'
        '  <Contents>\n'
        '    <Content ignore="false" zipEntry="certs/truststore-root.p12">\n'
        '      <Parameter name="name" value="Socialmesh CA"/>\n'
        '    </Content>\n'
        '    <Content ignore="false" zipEntry="certs/user.p12">\n'
        '      <Parameter name="name" value="Client Certificate"/>\n'
        '    </Content>\n'
        '    <Content ignore="false" zipEntry="preference.pref">\n'
        '      <Parameter name="name" value="TAK Server Connection"/>\n'
        '    </Content>\n'
        '  </Contents>\n'
        '</MissionPackageManifest>';
  }

  String _buildPreferences(String host, int port, String callsign) {
    return '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<preferences>\n'
        '  <preference version="1" name="com.atakmap.app_preferences">\n'
        '    <entry key="locationCallsign" class="class java.lang.String">$callsign</entry>\n'
        '    <entry key="connectString0" class="class java.lang.String">$host:$port:ssl</entry>\n'
        '    <entry key="caLocation" class="class java.lang.String">cert/truststore-root.p12</entry>\n'
        '    <entry key="certificateLocation" class="class java.lang.String">cert/user.p12</entry>\n'
        '    <entry key="clientPassword" class="class java.lang.String">atakatak</entry>\n'
        '    <entry key="caPassword" class="class java.lang.String">atakatak</entry>\n'
        '  </preference>\n'
        '</preferences>';
  }

  void _addTextFile(Archive archive, String name, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }
}
