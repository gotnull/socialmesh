// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:socialmesh/providers/file_transfer_providers.dart';
import 'package:socialmesh/services/file_transfer/file_transfer_engine.dart';
import 'package:socialmesh/services/protocol/socialmesh/sm_file_transfer.dart';

final class _MemoryFile extends PlatformFile {
  final bool fails;
  _MemoryFile({this.fails = false});

  @override
  String get name => 'sample.txt';
  @override
  Uri get uri => Uri.parse('data:text/plain;base64,aGk=');
  @override
  XFile get xFile => XFile.fromData(Uint8List.fromList([104, 105]), name: name);
  @override
  int lengthSync() => 2;
  @override
  Future<int> length() async => 2;
  @override
  Future<Uint8List> readAsBytes() async {
    if (fails) throw StateError('Selected file is unreadable');
    return Uint8List.fromList([104, 105]);
  }

  @override
  Stream<Uint8List> readAsByteStream() => Stream.fromFuture(readAsBytes());
}

class _Picker extends FilePickerPlatform {
  PlatformFile? file;
  _Picker(this.file);

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => file;
}

class _Transfers extends FileTransferStateNotifier {
  int sends = 0;
  Uint8List? selectedBytes;
  String? selectedName;
  String? selectedMime;
  int? selectedTarget;

  @override
  FileTransferListState build() => const FileTransferListState();

  @override
  Future<FileTransferState?> sendFile({
    required String filename,
    required String mimeType,
    required Uint8List fileBytes,
    int? targetNodeNum,
    FileTransportMode transportMode = FileTransportMode.auto,
  }) async {
    sends++;
    selectedBytes = fileBytes;
    selectedName = filename;
    selectedMime = mimeType;
    selectedTarget = targetNodeNum;
    return null;
  }
}

void main() {
  late FilePickerPlatform originalPicker;
  late _Transfers transfers;
  late ProviderContainer container;
  setUp(() {
    originalPicker = FilePickerPlatform.instance;
    transfers = _Transfers();
    container = ProviderContainer(
      overrides: [fileTransferStateProvider.overrideWith(() => transfers)],
    );
    container.read(fileTransferStateProvider);
  });
  tearDown(() {
    FilePickerPlatform.instance = originalPicker;
    container.dispose();
  });

  test('cancelled selection does not initiate a transfer', () async {
    FilePickerPlatform.instance = _Picker(null);
    expect(await transfers.pickAndSendFile(), isNull);
    expect(transfers.sends, 0);
  });

  test('reads selected bytes when there is no local disk path', () async {
    final file = _MemoryFile();
    expect(file.path, isNull);
    FilePickerPlatform.instance = _Picker(file);
    await transfers.pickAndSendFile(targetNodeNum: 20);
    expect(transfers.selectedBytes, [104, 105]);
    expect(transfers.selectedName, 'sample.txt');
    expect(transfers.selectedMime, 'text/plain');
    expect(transfers.selectedTarget, 20);
    expect(transfers.sends, 1);
  });

  test('read failures reach the caller without starting a transfer', () async {
    FilePickerPlatform.instance = _Picker(_MemoryFile(fails: true));
    await expectLater(transfers.pickAndSendFile(), throwsStateError);
    expect(transfers.sends, 0);
  });
}
