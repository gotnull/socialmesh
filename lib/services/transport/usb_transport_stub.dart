// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import '../../core/platform/noop_device_transport.dart';
import '../../core/transport.dart';

/// Web-build stub for [createUsbTransport]. The real [UsbTransport] pulls
/// in `package:usb_serial`, which transitively imports `dart:io` and so
/// fails web compilation. Routing every USB construction through this
/// factory keeps the web build green while preserving runtime parity on
/// mobile via the conditional import in `usb_transport_factory.dart`.
DeviceTransport createUsbTransport() => NoopDeviceTransport(TransportType.usb);
