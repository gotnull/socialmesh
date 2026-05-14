// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Conditional-import factory for the USB serial transport.
//
// usb_transport.dart statically imports package:usb_serial, which
// transitively pulls dart:io. A direct `import 'usb_transport.dart'`
// from a web-reachable path therefore fails `flutter build web` even
// when the runtime capability gate would have prevented construction.
// Routing every USB construction through this factory shifts the
// web/io split to a single conditional import: the web build resolves
// the stub variant; native builds resolve the real implementation.
//
// Callers should still gate on platformCapabilitiesProvider.supportsSerial
// before calling createUsbTransport() so the conditional-import
// indirection is never relied on for runtime correctness, only build
// shape.

export 'usb_transport_stub.dart'
    if (dart.library.io) 'usb_transport.dart'
    show createUsbTransport;
