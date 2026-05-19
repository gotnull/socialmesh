// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Shared catalogue of built-in ringtone presets. Mirrors the list
/// embedded in `lib/features/settings/ringtone_screen.dart`. Kept here
/// as a separate const so MeshCore screens can pick from the same set
/// without touching the Meshtastic ringtone screen file.
///
/// If the upstream Meshtastic list adds / removes entries, this file
/// should be updated to match - tracked as a parity drift risk in the
/// MeshCore parity audit Row 53.
class RingtonePreset {
  final String name;
  final String rtttl;
  final String description;

  const RingtonePreset({
    required this.name,
    required this.rtttl,
    required this.description,
  });
}

/// Number of built-in presets surfaced by default before the user
/// expands the full list. The first 10 entries are the hand-ordered
/// classics (Default, Nokia, Mario, Zelda, utility alerts); past 10
/// the list becomes alphabetical band names which feel like library
/// content. Matches the Meshtastic ringtone screen behaviour.
const int kFeaturedBuiltInRingtoneCount = 10;

const List<RingtonePreset> builtInRingtonePresets = <RingtonePreset>[
  RingtonePreset(
    name: 'Meshtastic Default',
    rtttl:
        '24:d=32,o=5,b=565:f6,p,f6,4p,p,f6,p,f6,2p,p,b6,p,b6,p,b6,p,b6,p,b,p,b,p,b,p,b,p,b,p,b,p,b,p,b,1p.,2p.,p',
    description: 'Default Meshtastic notification',
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
  RingtonePreset(
    name: '007',
    rtttl:
        '007:d=4,o=5,b=320:c,8d,8d,d,2d,c,c,c,c,8d#,8d#,2d#,d,d,d,c,8d,8d,d,2d,c,c,c,c,8d#,8d#,d#,2d#,d,c#,c,c6,1b.,g,f,1g.',
    description: 'James Bond theme',
  ),
  RingtonePreset(
    name: 'Addams Family',
    rtttl:
        'Addams Family:d=8,o=5,b=160:c,4f,a,4f,c,4b4,2g,f,4e,g,4e,g4,4c,2f,c,4f,a,4f,c,4b4,2g,f,4e,c,4d,e,1f,c,d,e,f,1p,d,e,f#,g,1p,d,e,f#,g,4p,d,e,f#,g,4p,c,d,e,f',
    description: 'The Addams Family theme',
  ),
  RingtonePreset(
    name: 'Alvin and the Chipmunks',
    rtttl:
        'Alvin and the Chipmonks:d=4,o=5,b=285:g,p,c,c,a,c,c,c,p,b,b,c6,c6,p,c,c,p,a,g,d,2g,d,2p,a,g,d,2g,a,p,g,p,c,c,a,c,c,c,p,b,b,c6,c6,p,c,c,p,a,g,d,2g,d,2p,a,a,g,2a,g,p,2a,b,2a,g,p,c,c,c,c,c,e,e,e,e,2a,g,2a,2g,2a,a,2g,2g.,p,2a,g,2a,g,p,c,c,c,c,c,e,e,e,e,2a,g,2a,2g,2c6,b,2b,1b,2c6',
    description: 'Alvin and the Chipmunks theme',
  ),
  RingtonePreset(
    name: 'Amazing Grace',
    rtttl:
        'Amazing Grace:d=16,o=5,b=80:8c,2f,a,g,f,2a,8a,8g,2f,4d,2c,8c,2f,a,g,f,2a,8g,8a,2c6.',
    description: 'Amazing Grace hymn',
  ),
  RingtonePreset(
    name: 'Axel F',
    rtttl:
        'Axel:d=8,o=5,b=125:16g,16g,a#.,16g,16p,16g,c6,g,f,4g,d.6,16g,16p,16g,d#6,d6,a#,g,d6,g6,16g,16f,16p,16f,d,a#,2g,4p,16f6,d6,c6,a#,4g,a#.,16g,16p,16g,c6,g,f,4g,d.6,16g,16p,16g,d#6,d6,a#,g,d6,g6,16g,16f,16p,16f,d,a#,2g',
    description: 'Axel F - Beverly Hills Cop',
  ),
  RingtonePreset(
    name: 'Back to the Future',
    rtttl:
        'Back to the Future:d=16,o=5,b=200:4g.,p,4c.,p,2f#.,p,g.,p,a.,p,8g,p,8e,p,8c,p,4f#,p,g.,p,a.,p,8g.,p,8d.,p,8g.,p,8d.6,p,4d.6,p,4c#6,p,b.,p,c#.6,p,2d.6',
    description: 'Back to the Future theme',
  ),
  RingtonePreset(
    name: 'Batman',
    rtttl:
        'Batman:d=8,o=5,b=180:d,d,c#,c#,c,c,c#,c#,d,d,c#,c#,c,c,c#,c#,d,d#,c,c#,c,c,c#,c#,f,p,4f',
    description: 'Batman theme',
  ),
  RingtonePreset(
    name: 'Beethoven',
    rtttl:
        'Bethoven:d=4,o=5,b=160:c,e,c,g,c,c6,8b,8a,8g,8a,8g,8f,8e,8f,8e,8d,c,e,g,e,c6,g.',
    description: 'Beethoven melody',
  ),
  RingtonePreset(
    name: 'Cantina',
    rtttl:
        'Cantina:d=8,o=5,b=250:a,p,d6,p,a,p,d6,p,a,d6,p,a,p,g#,4a,a,g#,a,4g,f#,g,f#,4f.,d.,16p,4p.,a,p,d6,p,a,p,d6,p,a,d6,p,a,p,g#,a,p,g,p,4g.,f#,g,p,c6,4a#,4a,4g',
    description: 'Star Wars Cantina Band',
  ),
  RingtonePreset(
    name: 'Death March',
    rtttl:
        'Death March:d=4,o=5,b=100:4c,16p,c,8c,32p,2c,d#,8d,32p,d,8c,32p,c,8b4,32p,2c.',
    description: 'Funeral march',
  ),
  RingtonePreset(
    name: 'Final Countdown',
    rtttl:
        'Final Countdown:d=16,o=5,b=125:b,a,4b,4e,4p,8p,c6,b,8c6,8b,4a,4p,8p,c6,b,4c6,4e,4p,8p,a,g,8a,8g,8f#,8a,4g.,f#,g,4a.,g,a,8b,8a,8g,8f#,4e,4c6,2b.,b,c6,b,a,1b',
    description: 'Final Countdown by Europe',
  ),
  RingtonePreset(
    name: 'Flintstones',
    rtttl:
        'Flintstones:d=8,o=5,b=200:g#,4c#,p,4c#6,a#,4g#,4c#,p,4g#,f#,f,f,f#,g#,4c#,4d#,2f,2p,4g#,4c#,p,4c#6,a#,4g#,4c#,p,4g#,f#,f,f,f#,g#,4c#,4d#,2c#',
    description: 'The Flintstones theme',
  ),
  RingtonePreset(
    name: 'Friends',
    rtttl:
        'Friends:d=4,o=5,b=80:c,g,a#4,f,c,g,a#4,8a#,8e,c,g,a#4,f,c,g,a#4,8a#,8e',
    description: 'Friends TV theme',
  ),
  RingtonePreset(
    name: 'Ghost Busters',
    rtttl:
        'Ghost Busters:d=8,o=5,b=145:16c6,32p,16c6,e6,c6,d6,a#,2p,32c6,32p,32c6,32p,c6,a#,c6',
    description: 'Ghostbusters theme',
  ),
  RingtonePreset(
    name: 'Greensleeves',
    rtttl:
        'Greensleaves:d=4,o=5,b=140:g,2a#,c6,d.6,8d#6,d6,2c6,a,f.,8g,a,2a#,g,g.,8f,g,2a,f,2d,g,2a#,c6,d.6,8e6,d6,2c6,a,f.,8g,a,a#.,8a,g,f#.,8e,f#,2g',
    description: 'Greensleeves folk song',
  ),
  RingtonePreset(
    name: 'Halloween',
    rtttl:
        'Halloween:d=8,o=5,b=180:d6,g,g,d6,g,g,d6,g,d#6,g,d6,g,g,d6,g,g,d6,g,d#6,g,c#6,f#,f#,c#6,f#,f#,c#6,f#,d6,f#,c#6,f#,f#,c#6,f#,f#,c#6,f#,d6,f#',
    description: 'Halloween theme',
  ),
  RingtonePreset(
    name: 'Imperial March',
    rtttl:
        'Star Wars:d=8,o=6,b=180:f5,f5,f5,2a#5.,2f.,d#,d,c,2a#.,4f.,d#,d,c,2a#.,4f.,d#,d,d#,2c,4p,f5,f5,f5,2a#5.,2f.,d#,d,c,2a#.,4f.,d#,d,c,2a#.,4f.,d#,d,d#,2c',
    description: 'Star Wars Imperial March',
  ),
  RingtonePreset(
    name: 'Jingle Bells',
    rtttl:
        'Jingle Bells:d=4,o=5,b=170:b,b,b,p,b,b,b,p,b,d6,g.,8a,2b.,8p,c6,c6,c6.,8c6,c6,b,b,8b,8b,b,a,a,b,2a,2d6',
    description: 'Jingle Bells Christmas',
  ),
  RingtonePreset(
    name: 'Knight Rider',
    rtttl:
        'Knight Rider:d=32,o=5,b=63:16e,f,e,8b,16e6,f6,e6,8b,16e,f,e,16b,16e6,4d6,8p,4p,16e,f,e,8b,16e6,f6,e6,8b,16e,f,e,16b,16e6,4f6',
    description: 'Knight Rider theme',
  ),
  RingtonePreset(
    name: 'Mission Impossible',
    rtttl:
        'Mission Impossible:d=16,o=5,b=100:32d,32d#,32d,32d#,32d,32d#,32d,32d#,32d,32d,32d#,32e,32f,32f#,32g,g,8p,g,8p,a#,p,c6,p,g,8p,g,8p,f,p,f#,p,g,8p,g,8p,a#,p,c6,p,g,8p,g,8p,f,p,f#,p,a#,g,2d,32p,a#,g,2c#,32p,a#,g,2c,p,a#4,c',
    description: 'Mission Impossible theme',
  ),
  RingtonePreset(
    name: 'Pager',
    rtttl: 'Pager:d=8,o=5,b=160:d6,16p,2d6,16p,d6,16p,2d6,16p,d6,16p,2d6.',
    description: 'Classic pager sound',
  ),
  RingtonePreset(
    name: 'Pink Panther',
    rtttl:
        'Piccolo:d=8,o=5,b=320:d6,4g6,4g,4g6,d6,e6,d6,b,4g,4d,g,a,b,c6,4d6,4g6,1d6,4d6,4g6,4g,4g6,d6,e6,b,4g,4d,f,g,a,b,4c6,4f6,1c6',
    description: 'Pink Panther theme',
  ),
  RingtonePreset(
    name: 'Simpsons',
    rtttl:
        'Simpsons:d=8,o=5,b=160:c.6,4e6,4f#6,a6,4g.6,4e6,4c6,a,f#,f#,f#,2g,p,p,f#,f#,f#,g,4a#.,c6,c6,c6,4c6',
    description: 'The Simpsons theme',
  ),
  RingtonePreset(
    name: 'Star Trek',
    rtttl: 'Star Trek:d=16,o=5,b=63:8f.,a#,4d#.6,8d6,a#.,g.,c.6,4f6',
    description: 'Star Trek theme',
  ),
  RingtonePreset(
    name: 'Superman',
    rtttl:
        'Super Man:d=8,o=6,b=180:g5,g5,g5,4c,c,2g,p,g,a.,16g,f,1g,p,g5,g5,g5,4c,c,2g,p,g,a.,16g,f,a,2g.,4p,c,c,c,2b.,4g.,c,c,c,2b.,4g.,c,c,c,b,a,b,2c7,c,c,c,c,c,2c.',
    description: 'Superman theme',
  ),
  RingtonePreset(
    name: 'Take On Me',
    rtttl:
        'Take On Me:d=8,o=5,b=160:f#,f#,f#,d,p,b4,p,e,p,e,p,e,g#,g#,a,b,a,a,a,e,p,d,p,f#,p,f#,p,f#,e,e,f#,e,f#,f#,f#,d,p,b4,p,e,p,e,p,e,g#,g#,a,b,a,a,a,e,p,d,p,f#,p,f#,p,f#,e,e5',
    description: 'Take On Me by A-ha',
  ),
  RingtonePreset(
    name: 'Titanic',
    rtttl:
        'Titanic:d=8,o=6,b=120:c,d,2e.,d,c,d,g,2g,f,e,4c,2a5,g5,f5,16d5,16e5,2d5,p,c,d,2e.,d,c,d,g,2g,e,g,2a,2g,16d,16e,2d.',
    description: 'My Heart Will Go On',
  ),
  RingtonePreset(
    name: 'Wannabe',
    rtttl:
        'Wannabe:d=8,o=5,b=125:16g,16g,16g,16g,g,a,g,e,p,16c,16d,16c,d,d,c,4e,4p,g,g,g,a,g,e,p,4c6,c6,b,g,a,16b,16a,4g',
    description: 'Wannabe by Spice Girls',
  ),
  RingtonePreset(
    name: 'YMCA',
    rtttl:
        'YMCA:d=8,o=5,b=160:c#6,a#,2p,a#,g#,f#,g#,a#,4c#6,a#,4c#6,d#6,a#,2p,a#,g#,f#,g#,a#,4c#6,a#,4c#6,d#6,b,2p,b,a#,g#,a#,b,4d#6,f#6,4d#6,4f.6,4d#.6,4c#.6,4b.,4a#,4g#',
    description: 'YMCA by Village People',
  ),
];
