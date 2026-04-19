// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

library;

enum MeshServiceSignalKind {
  checkIn(0),
  needHelp(1),
  hazard(2),
  meetHere(3),
  relayActive(4);

  const MeshServiceSignalKind(this.code);

  final int code;

  static MeshServiceSignalKind fromCode(int code) {
    for (final value in values) {
      if (value.code == code) return value;
    }
    return MeshServiceSignalKind.checkIn;
  }

  static MeshServiceSignalKind fromStorage(Object? value) {
    if (value is String) {
      for (final kind in values) {
        if (kind.name == value) return kind;
      }
    }
    return MeshServiceSignalKind.checkIn;
  }
}
