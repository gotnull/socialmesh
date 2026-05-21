// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// One row in the Watch channel picker.
class WatchCompanionChannelPreview {
  const WatchCompanionChannelPreview({
    required this.index,
    required this.name,
    required this.isDefault,
  });

  /// Channel index as accepted by the active protocol's send API.
  /// For Meshtastic this is the channel-set index; for MeshCore this is
  /// always 0 in v1 (public channel only).
  final int index;

  final String name;

  /// True for the channel that should be pre-selected on the Watch quick-send
  /// screen. The phone-side facade picks this from the
  /// `watchDefaultChannelIndex` setting; exactly one entry should carry
  /// `isDefault == true` per snapshot.
  final bool isDefault;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'index': index,
    'name': name,
    'isDefault': isDefault,
  };

  factory WatchCompanionChannelPreview.fromJson(Map<String, dynamic> json) {
    return WatchCompanionChannelPreview(
      index: json['index'] as int,
      name: json['name'] as String,
      isDefault: json['isDefault'] as bool,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WatchCompanionChannelPreview &&
          other.index == index &&
          other.name == name &&
          other.isDefault == isDefault;

  @override
  int get hashCode => Object.hash(index, name, isDefault);

  @override
  String toString() =>
      'WatchCompanionChannelPreview(index: $index, '
      'name: $name, default: $isDefault)';
}
