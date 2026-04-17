// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// NodeBoard theme model — controls visual style of a board.

import 'nodeboard_enums.dart';

class NodeBoardTheme {
  final String id;
  final String name;
  final StyleMode styleMode;
  final String promptStyle;
  final String accentPreset;
  final String chromeVariant;
  final String? asciiHeaderTemplate;
  final bool supportsAnsi;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const NodeBoardTheme({
    required this.id,
    required this.name,
    this.styleMode = StyleMode.native,
    this.promptStyle = 'chevron',
    this.accentPreset = 'magenta',
    this.chromeVariant = 'glass',
    this.asciiHeaderTemplate,
    this.supportsAnsi = false,
    this.createdAt,
    this.updatedAt,
  });

  factory NodeBoardTheme.fromJson(Map<String, dynamic> json) => NodeBoardTheme(
    id: json['id'] as String,
    name: json['name'] as String,
    styleMode: StyleMode.fromJson(json['styleMode'] as String? ?? 'native'),
    promptStyle: json['promptStyle'] as String? ?? 'chevron',
    accentPreset: json['accentPreset'] as String? ?? 'magenta',
    chromeVariant: json['chromeVariant'] as String? ?? 'glass',
    asciiHeaderTemplate: json['asciiHeaderTemplate'] as String?,
    supportsAnsi: json['supportsAnsi'] as bool? ?? false,
    createdAt: (json['createdAt'] as String?) != null
        ? DateTime.parse(json['createdAt'] as String)
        : null,
    updatedAt: (json['updatedAt'] as String?) != null
        ? DateTime.parse(json['updatedAt'] as String)
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'styleMode': styleMode.toJson(),
    'promptStyle': promptStyle,
    'accentPreset': accentPreset,
    'chromeVariant': chromeVariant,
    'asciiHeaderTemplate': asciiHeaderTemplate,
    'supportsAnsi': supportsAnsi,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
  };

  String renderHeader(String boardTitle, String sysopName) {
    if (asciiHeaderTemplate == null) return boardTitle;
    return asciiHeaderTemplate!
        .replaceAll('{{BOARD_TITLE}}', boardTitle)
        .replaceAll('{{SYSOP_NAME}}', sysopName);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is NodeBoardTheme && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
