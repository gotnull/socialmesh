// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Shared enums for the NodeBoard feature.

enum BoardVisibility {
  public_,
  unlisted,
  private_;

  String toJson() => switch (this) {
    public_ => 'public',
    unlisted => 'unlisted',
    private_ => 'private',
  };

  static BoardVisibility fromJson(String value) => switch (value) {
    'public' => BoardVisibility.public_,
    'unlisted' => BoardVisibility.unlisted,
    'private' => BoardVisibility.private_,
    _ => BoardVisibility.public_,
  };
}

enum SectionVisibility {
  public_,
  membersOnly,
  sysopOnly;

  String toJson() => switch (this) {
    public_ => 'public',
    membersOnly => 'membersOnly',
    sysopOnly => 'sysopOnly',
  };

  static SectionVisibility fromJson(String value) => switch (value) {
    'public' => SectionVisibility.public_,
    'membersOnly' => SectionVisibility.membersOnly,
    'sysopOnly' => SectionVisibility.sysopOnly,
    _ => SectionVisibility.public_,
  };
}

enum PostingPolicy {
  sysopOnly,
  authenticatedUsers,
  guestsAllowed,
  readOnly;

  String toJson() => name;

  static PostingPolicy fromJson(String value) => switch (value) {
    'sysopOnly' => PostingPolicy.sysopOnly,
    'authenticatedUsers' => PostingPolicy.authenticatedUsers,
    'guestsAllowed' => PostingPolicy.guestsAllowed,
    'readOnly' => PostingPolicy.readOnly,
    _ => PostingPolicy.authenticatedUsers,
  };
}

enum BodyFormat {
  plaintext,
  markdown;

  String toJson() => name;

  static BodyFormat fromJson(String value) => switch (value) {
    'plaintext' => BodyFormat.plaintext,
    'markdown' => BodyFormat.markdown,
    _ => BodyFormat.plaintext,
  };
}

enum StyleMode {
  native,
  terminal,
  both;

  String toJson() => name;

  static StyleMode fromJson(String value) => switch (value) {
    'native' => StyleMode.native,
    'terminal' => StyleMode.terminal,
    'both' => StyleMode.both,
    _ => StyleMode.native,
  };
}

enum TerminalCommand {
  help,
  list,
  open,
  post,
  reply,
  back,
  sections,
  about,
  guestbook,
  quit,
  unknown,
}

enum TerminalScreen {
  splash,
  boardHome,
  sectionList,
  threadList,
  threadView,
  compose,
  help,
}
