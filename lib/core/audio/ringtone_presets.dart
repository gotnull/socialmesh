// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Core ringtone preset data shared by Meshtastic and MeshCore
// ringtone screens. The Meshtastic ringtone screen carries its own
// inline 40-preset list today; this file extracts the 10 "classics"
// that ship in both surfaces. The remaining 30 alphabetical band-name
// presets stay behind the Premium library gate on either side.
//
// Day-1 drift policy: keep the 10 entries here in sync with the first
// 10 entries of `_builtInPresets` in `ringtone_screen.dart`. If the
// Meshtastic side updates a preset, mirror the change here. A future
// refactor can collapse both to a single source.

/// One ringtone option presented to the user.
class RingtonePreset {
  /// Display name shown in the picker.
  final String name;

  /// Ring Tone Text Transfer Language string. Consumed by
  /// `NotificationSoundService.prepareSoundFromRtttl` to synthesise a
  /// cached WAV file on demand.
  final String rtttl;

  /// One-line caption shown under the name.
  final String description;

  const RingtonePreset({
    required this.name,
    required this.rtttl,
    required this.description,
  });
}

/// The 10 featured presets - same ordering as `ringtone_screen.dart`.
const List<RingtonePreset> kFeaturedRingtonePresets = [
  RingtonePreset(
    name: 'Meshtastic Default',
    rtttl:
        '24:d=32,o=5,b=565:f6,p,f6,4p,p,f6,p,f6,2p,p,b6,p,b6,p,b6,p,b6,p,b,p,b,p,b,p,b,p,b,p,b,p,b,p,b,1p.,2p.,p',
    description: 'Default mesh notification',
  ),
  RingtonePreset(
    name: 'Nokia Ringtone',
    rtttl: '24:d=4,o=5,b=180:8e6,8d6,f#,g#,8c#6,8b,d,e,8b,8a,c#,e,2a',
    description: 'Classic Nokia tune',
  ),
  RingtonePreset(
    name: 'Zelda Get Item',
    rtttl: '24:d=16,o=5,b=120:g,c6,d6,2g6',
    description: 'Legend of Zelda item sound',
  ),
  RingtonePreset(
    name: 'Mario Coin',
    rtttl: '24:d=8,o=6,b=200:b,e7',
    description: 'Super Mario coin collect',
  ),
  RingtonePreset(
    name: 'Mario Power Up',
    rtttl: 'powerup:d=16,o=5,b=200:g,a,b,c6,d6,e6,f#6,g6,a6,b6,2c7',
    description: 'Super Mario power up',
  ),
  RingtonePreset(
    name: 'Mario Theme',
    rtttl: '24:d=4,o=5,b=100:16e6,16e6,32p,8e6,16c6,8e6,8g6,8p,8g',
    description: 'Super Mario theme (short)',
  ),
  RingtonePreset(
    name: 'Morse CQ',
    rtttl: '24:d=16,o=6,b=120:8c,p,c,p,8c,p,c,4p,8c,p,8c,p,c,p,8c,8p',
    description: 'Morse code CQ call',
  ),
  RingtonePreset(
    name: 'Simple Beep',
    rtttl: '24:d=4,o=5,b=120:c6,p,c6',
    description: 'Simple double beep',
  ),
  RingtonePreset(
    name: 'Alert',
    rtttl: '24:d=8,o=6,b=140:c,e,g,c7,p,c7,g,e,c',
    description: 'Ascending alert tone',
  ),
  RingtonePreset(
    name: 'Ping',
    rtttl: '24:d=16,o=6,b=200:e,p,e',
    description: 'Quick ping sound',
  ),
];
