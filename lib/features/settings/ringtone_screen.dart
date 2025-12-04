import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../providers/app_providers.dart';
import '../../services/audio/rtttl_library_service.dart';
import '../../services/audio/rtttl_player.dart';

/// Preset ringtones with name and RTTTL string
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

/// Built-in ringtone presets
const _builtInPresets = [
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
    name: '7Days',
    rtttl:
        '7Days:d=16,o=6,b=140:g#,d#,8a#5,g#,d#,8a#5,g#,d#,8a#5,g#,d#,8a#5,f,1p5,g#,d#,8a#5,g#,d#,8a#5,g#,d#,8a#5,g#,d#,8a#5,f,1p5,g#,d#,8c,g#,d#,8c,g#,d#,8c,g#,d#,8c,f,1p5,g#,d#,8c,g#,d#,8c,g#,d#,8c,g#,d#,8c,f,1p5,d#,c,8g#5,d#,c,8g#5,d#,c,8g#5,d#,c,8g#5,f,1p5,d#,c,8g#5,d#,c,8g#5,d#,c,8g#5,d#,c,8g#5,f,1p5,d#,c#,8a#5,d#,c#,8a#5,d#,c#,8a#5,d#,c#,8a#5,f,1p5,d#,c#,8a#5,d#,c#,8a#5,d#,c#,8a#5,d#,c#,8a#5,f.',
    description: '7 Days melody',
  ),
  RingtonePreset(
    name: 'Addams Family',
    rtttl:
        'Addams Family:d=8,o=5,b=160:c,4f,a,4f,c,4b4,2g,f,4e,g,4e,g4,4c,2f,c,4f,a,4f,c,4b4,2g,f,4e,c,4d,e,1f,c,d,e,f,1p,d,e,f#,g,1p,d,e,f#,g,4p,d,e,f#,g,4p,c,d,e,f',
    description: 'The Addams Family theme',
  ),
  RingtonePreset(
    name: 'Agadoo',
    rtttl:
        'Agadoo:d=8,o=5,b=125:b,g#,4e,e,e,4e,e,e,e,e,d#,e,4f#,a,f#,4d#,d#,d#,4d#,d#,d#,d#,d#,c#,d#,4e',
    description: 'Agadoo party song',
  ),
  RingtonePreset(
    name: 'Alice Cooper - Poison',
    rtttl:
        'Alice Cooper-Poison:d=8,o=5,b=112:d,d,a,d,e6,d,d6,d,f#,g,c6,f#,g,c6,e,d,d,d,a,d,e6,d,d6,d,f#,g,c6,f#,g,c6,e,d,c,d,a,d,e6,d,d6,d,f#,g,c6,f#,g,c6,e,d,c,d,a,d,e6,d,d6,d,a,d,e6,d,d6',
    description: 'Alice Cooper Poison riff',
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
    name: 'Ba Ba Black Sheep',
    rtttl:
        'Ba Ba Black Sheep:d=8,o=5,b=150:c,4p,c,4p,g,4p,g,4p,4a,4b,4c6,4a,4g,4p,f,4p,f,4p,e,4p,e,4p,d,4p,d,4p,4c',
    description: 'Ba Ba Black Sheep nursery rhyme',
  ),
  RingtonePreset(
    name: 'Back to the Future',
    rtttl:
        'Back to the Future:d=16,o=5,b=200:4g.,p,4c.,p,2f#.,p,g.,p,a.,p,8g,p,8e,p,8c,p,4f#,p,g.,p,a.,p,8g.,p,8d.,p,8g.,p,8d.6,p,4d.6,p,4c#6,p,b.,p,c#.6,p,2d.6',
    description: 'Back to the Future theme',
  ),
  RingtonePreset(
    name: 'Barbie Girl',
    rtttl:
        'Barbie Girl:d=8,o=5,b=125:g#,e,g#,c#6,4a,4p,f#,d#,f#,b,4g#,f#,e,4p,e,c#,4f#,4c#,4p,f#,e,4g#,4f#',
    description: 'Barbie Girl by Aqua',
  ),
  RingtonePreset(
    name: 'Batman',
    rtttl:
        'Batman:d=8,o=5,b=180:d,d,c#,c#,c,c,c#,c#,d,d,c#,c#,c,c,c#,c#,d,d#,c,c#,c,c,c#,c#,f,p,4f',
    description: 'Batman theme',
  ),
  RingtonePreset(
    name: 'Benny Hill',
    rtttl:
        'Benny Hill:d=16,o=5,b=125:8d.,e,8g,8g,e,d,a4,b4,d,b4,8e,d,b4,a4,b4,8a4,a4,a#4,b4,d,e,d,4g,4p,d,e,d,8g,8g,e,d,a4,b4,d,b4,8e,d,b4,a4,b4,8d,d,d,f#,a,8f,4d,4p,d,e,d,8g,g,g,8g,g,g,8g,8g,e,8e.,8c,8c,8c,8c,e,g,a,g,a#,8g,a,b,a#,b,a,b,8d6,a,b,d6,8b,8g,8d,e6,b,b,d,8a,8g,4g',
    description: 'Benny Hill chase theme',
  ),
  RingtonePreset(
    name: 'Beethoven',
    rtttl:
        'Bethoven:d=4,o=5,b=160:c,e,c,g,c,c6,8b,8a,8g,8a,8g,8f,8e,8f,8e,8d,c,e,g,e,c6,g.',
    description: 'Beethoven melody',
  ),
  RingtonePreset(
    name: 'Birdy Song',
    rtttl:
        'Birdy Song:d=16,o=5,b=100:g,g,a,a,e,e,8g,g,g,a,a,e,e,8g,g,g,a,a,c6,c6,8b,8b,8a,8g,8f,f,f,g,g,d,d,8f,f,f,g,g,d,d,8f,f,f,g,g,a,b,8c6,8a,8g,8e,4c',
    description: 'The Birdie Song',
  ),
  RingtonePreset(
    name: 'Cantina',
    rtttl:
        'Cantina:d=8,o=5,b=250:a,p,d6,p,a,p,d6,p,a,d6,p,a,p,g#,4a,a,g#,a,4g,f#,g,f#,4f.,d.,16p,4p.,a,p,d6,p,a,p,d6,p,a,d6,p,a,p,g#,a,p,g,p,4g.,f#,g,p,c6,4a#,4a,4g',
    description: 'Star Wars Cantina Band',
  ),
  RingtonePreset(
    name: 'Chariots of Fire',
    rtttl:
        'Chariots of Fire:d=16,o=5,b=85:8c#,f#.,g#.,a#.,4g#,4f,8p,8c#,f#.,g#.,a#.,2g#,8p,8c#,f#.,g#.,a#.,4g#,4f,8p,8f,f#.,f.,c#.,2c#',
    description: 'Chariots of Fire theme',
  ),
  RingtonePreset(
    name: 'Coca Cola',
    rtttl:
        'Coca Cola:d=16,o=5,b=125:f#6,p,f#6,p,f#6,p,f#6,p,4g6,f#6,p,4e6,p,e6,p,8a6,4f#6,4d6',
    description: 'Coca Cola jingle',
  ),
  RingtonePreset(
    name: 'Dallas',
    rtttl:
        'Dallas:d=8,o=5,b=125:e,4a.,e,4e.6,a,4c#6,b,c#6,4a,4e,4a,4f#6,4e6,c#6,d6,2e.6,p,e,4a,4f#6,4e6,c#6,d6,4e6,b,c#6,4a,4e,4a,c#6,d6,4b.,a,2a',
    description: 'Dallas TV theme',
  ),
  RingtonePreset(
    name: 'Death March',
    rtttl:
        'Death March:d=4,o=5,b=100:4c,16p,c,8c,32p,2c,d#,8d,32p,d,8c,32p,c,8b4,32p,2c.',
    description: 'Funeral march',
  ),
  RingtonePreset(
    name: 'Deep Purple - Smoke on the Water',
    rtttl:
        'Deep Purple-Smoke on the Water:d=4,o=4,b=112:c,d#,f.,c,d#,8f#,f,p,c,d#,f.,d#,c,2p,8p,c,d#,f.,c,d#,8f#,f,p,c,d#,f.,d#,c',
    description: 'Smoke on the Water riff',
  ),
  RingtonePreset(
    name: 'Entertainer',
    rtttl:
        'Entertainer:d=8,o=5,b=140:d,d#,e,4c6,e,4c6,e,2c.6,c6,d6,d#6,e6,c6,d6,4e6,b,4d6,2c6,4p,d,d#,e,4c6,e,4c6,e,2c.6,p,a,g,f#,a,c6,4e6,d6,c6,a,2d6',
    description: 'The Entertainer ragtime',
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
    name: 'Funky Town',
    rtttl:
        'Funky Town:d=8,o=4,b=125:c6,c6,a#5,c6,p,g5,p,g5,c6,f6,e6,c6,2p,c6,c6,a#5,c6,p,g5,p,g5,c6,f6,e6,c6',
    description: 'Funky Town disco',
  ),
  RingtonePreset(
    name: 'Futurama',
    rtttl:
        'Futurama:d=8,o=5,b=112:e,4e,4e,a,4a,4d,4d,e,4e,4e,e,4a,4g#,4d,d,f#,f#,4e,4e,e,4a,4g#,4b,16b,16b,g,g,f#,f#,4e,4e,a,4a,4d,4d,e,g,f#,4e,e,4a,4g#,4d,d,f#,f#,4e,4e,e,4a,4g#,4b,16b,16b,g,g,f#,f#,p,16e,16e,e,d#,d,d,c#,c#',
    description: 'Futurama theme',
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
    name: 'Hawaii 5-0',
    rtttl:
        'Hawaii 5 0:d=16,o=6,b=240:8g#5,p,8g#5,p,8b5,p,4d#,p,2c#.,p,2g#5.,p,8g#5,p,8g#5,p,8f#5,p,4b5,p,1g#5,4p.,8g#5,p,8g#5,p,8b5,p,4d#,p,2c#,8p,2g#.,8p,8f#,p,8f#,p,8d#,p,4b5,p,1g#.,4p,2b,p,8a,8g#,8f#,8e,8d#,8c#,8d#,8b5,2c#,4p,8c#,p,8b,8a,8g,8f#,8d#,8c#,8b5,8c#,4d#,8c#,p,4b5,p,4c#.,p,2g#,4p,8f#,p,8f#,p,8d#,p,4b5,p,1c#6',
    description: 'Hawaii Five-0 theme',
  ),
  RingtonePreset(
    name: 'He-Man',
    rtttl:
        'Heman:d=8,o=6,b=160:g,g,g,4g,4e,g,a,g,f,4g,4c,g,a,g,f,4g,4e,c,2d.,4p,4e.,4a5,4c,e,f#,e,d,4e,4a5,e,f#,e,d,4e,4a5,g5,2a5',
    description: 'He-Man theme',
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
    name: 'Let It Be',
    rtttl:
        'Let it be:d=8,o=5,b=100:16e6,d6,4c6,16e6,g6,a6,g.6,16g6,g6,e6,16d6,c6,16a,g,4e.6,4p,e6,16e6,f.6,e6,e6,d6,16p,16e6,16d6,d6,2c.6.',
    description: 'Let It Be by The Beatles',
  ),
  RingtonePreset(
    name: 'Macarena',
    rtttl:
        'Macarena:d=8,o=5,b=180:f,f,f,4f,f,f,f,f,f,f,f,a,c,c,4f,f,f,4f,f,f,f,f,f,f,d,c,4p,4f,f,f,4f,f,f,f,f,f,f,f,a,4p,2c.6,4a,c6,a,f,4p,2p',
    description: 'Macarena dance',
  ),
  RingtonePreset(
    name: 'Mission Impossible',
    rtttl:
        'Mission Impossible:d=16,o=5,b=100:32d,32d#,32d,32d#,32d,32d#,32d,32d#,32d,32d,32d#,32e,32f,32f#,32g,g,8p,g,8p,a#,p,c6,p,g,8p,g,8p,f,p,f#,p,g,8p,g,8p,a#,p,c6,p,g,8p,g,8p,f,p,f#,p,a#,g,2d,32p,a#,g,2c#,32p,a#,g,2c,p,a#4,c',
    description: 'Mission Impossible theme',
  ),
  RingtonePreset(
    name: 'Monty Python',
    rtttl:
        'Monty Python:d=8,o=5,b=180:d#6,d6,4c6,b,4a#,a,4g#,g,f,g,g#,4g,f,2a#,p,a#,g,p,g,g,f#,g,d#6,p,a#,a#,p,g,g#,p,g#,g#,p,a#,2c6,p,g#,f,p,f,f,e,f,d6,p,c6,c6,p,g#,g,p,g,g,p,g#,2a#,p,a#,g,p,g,g,f#,g,g6,p,d#6,d#6,p,a#,a,p,f6,f6,p,f6,2f6,p,d#6,4d6,f6,f6,e6,f6,4c6,f6,f6,e6,f6,a#,p,a,a#,p,a,2a#',
    description: 'Monty Python theme',
  ),
  RingtonePreset(
    name: 'Muppets',
    rtttl:
        'Muppets:d=4,o=5,b=250:c6,c6,a,b,8a,b,g,p,c6,c6,a,8b,8a,8p,g.,p,e,e,g,f,8e,f,8c6,8c,8d,e,8e,8e,8p,8e,g,2p,c6,c6,a,b,8a,b,g,p,c6,c6,a,8b,a,g.,p,e,e,g,f,8e,f,8c6,8c,8d,e,8e,d,8d,c',
    description: 'The Muppet Show theme',
  ),
  RingtonePreset(
    name: 'Pager',
    rtttl: 'Pager:d=8,o=5,b=160:d6,16p,2d6,16p,d6,16p,2d6,16p,d6,16p,2d6.',
    description: 'Classic pager sound',
  ),
  RingtonePreset(
    name: 'Phantom of the Opera',
    rtttl:
        'Phantom:d=8,o=5,b=120:4d6,d6,4a6,a6,4b6,g6,4a6,a6,4d6,d6,4a6,a6,a6,g6,f6,4e6,e6,4d6,d6,4a6,a6,4b6,g6,4a6,a6,4d6,d6,4a6,a6,f6,e6,c#6,4d6,d6.',
    description: 'Phantom of the Opera',
  ),
  RingtonePreset(
    name: 'Pink Panther',
    rtttl:
        'Piccolo:d=8,o=5,b=320:d6,4g6,4g,4g6,d6,e6,d6,b,4g,4d,g,a,b,c6,4d6,4g6,1d6,4d6,4g6,4g,4g6,d6,e6,b,4g,4d,f,g,a,b,4c6,4f6,1c6',
    description: 'Pink Panther theme',
  ),
  RingtonePreset(
    name: 'Popcorn',
    rtttl:
        'Popcorn:d=16,o=5,b=160:a,p,g,p,a,p,e,p,c,p,e,p,8a4,8p,a,p,g,p,a,p,e,p,c,p,e,p,8a4,8p,a,p,b,p,c6,p,b,p,c6,p,a,p,b,p,a,p,b,p,g,p,a,p,g,p,a,p,f,8a,8p,a,p,g,p,a,p,e,p,c,p,e,p,8a4,8p,a,p,g,p,a,p,e,p,c,p,e,p,8a4,8p,a,p,b,p,c6,p,b,p,c6,p,a,p,b,p,a,p,b,p,g,p,a,p,g,p,a,p,b,4c6',
    description: 'Popcorn electronic',
  ),
  RingtonePreset(
    name: 'Popeye',
    rtttl:
        'Popeye:d=8,o=6,b=160:a5,c,c,c,4a#5,a5,4c,2p,c,d,a#5,d,4f,d,2c,p,c,d,a#5,d,f,e,d,c,d,c,a5,f5,a5,c,d,c,4a#5,g5,2f5',
    description: 'Popeye the Sailor Man',
  ),
  RingtonePreset(
    name: 'Scatman',
    rtttl:
        'Scatman:d=16,o=5,b=200:8b,b,32p,8b,b,32p,8b,2d6,p,c#.6,p.,8d6,p,c#6,8b,p,8f#,2p.,c#6,8p,d.6,p.,c#6,b,8p,8f#,2p,32p,2d6,p,c#6,8p,d.6,p.,c#6,a.,p.,8e,2p.,c#6,8p,d.6,p.,c#6,b,8p,8b,b,32p,8b,b,32p,8b,2d6,p,c#.6,p.,8d6,p,c#6,8b,p,8f#,2p.,c#6,8p,d.6,p.,c#6,b,8p,8f#,2p,32p,2d6,p,c#6,8p,d.6,p.,c#6,a.,p.,8e,2p.,c#6,8p,d.6,p.,c#6,a,8p,8e,2p,32p,f#.6,p.,b.,p.',
    description: 'Scatman John',
  ),
  RingtonePreset(
    name: 'Scooby Doo',
    rtttl:
        'Scooby Doo:d=8,o=6,b=160:e,e,d,d,2c,d,4e,2a5,a5,4b5,4g5,4e,d,4c,d,2e,4p,e,e,d,d,2c,d,4f,2a5,a5,4b5,4g5,4e,d,2c',
    description: 'Scooby Doo theme',
  ),
  RingtonePreset(
    name: 'Sesame Street',
    rtttl:
        'Sesame Street:d=4,o=5,b=160:2c6,a,2f,8f,8g,a,p,2c6,a,1f,p,2c6,a,2f,8f,8g,a,2b,c6,2d6,p,8c6,8d6,d#6,d6,c6,a,g,8g,8a,a#,a,8g,8c,8c,1c',
    description: 'Sesame Street theme',
  ),
  RingtonePreset(
    name: 'Simpsons',
    rtttl:
        'Simpsons:d=8,o=5,b=160:c.6,4e6,4f#6,a6,4g.6,4e6,4c6,a,f#,f#,f#,2g,p,p,f#,f#,f#,g,4a#.,c6,c6,c6,4c6',
    description: 'The Simpsons theme',
  ),
  RingtonePreset(
    name: 'Smurfs',
    rtttl:
        'Smurfs:d=4,o=5,b=200:2c6,f.6,8c6,d6,a#,2g,c.6,8a,f,a,2g,p,16g,16a,16a#,16b,2c6,f.6,8c6,d6,a#,2g,c.6,8a,a#,e,2f,p,16g,16a,16a#,16b,2c6,f.6,8c6,d6,a#,2g,c.6,8a,f,a,2g,p,16g,16a,16a#,16b,2c6,f.6,8c6,d6,a#,2g,c.6,8a,a#,e,2f.,1p',
    description: 'The Smurfs theme',
  ),
  RingtonePreset(
    name: 'South Park',
    rtttl:
        'South Park:d=8,o=5,b=125:e,e,e,16e,e,16e,p,e,e,e,e,e,16p,16e,e,2p,g,g,4g,16b,16b,b,e,a#,16g,16g,g,16f#,16f#,f#,e',
    description: 'South Park theme',
  ),
  RingtonePreset(
    name: 'Spiderman',
    rtttl:
        'Spiderman:d=4,o=6,b=200:c,8d#,g.,p,f#,8d#,c.,p,c,8d#,g,8g#,g,f#,8d#,c.,p,f,8g#,c.7,p,a#,8g#,f.,p,c,8d#,g.,p,f#,8d#,c,p,8g#,2g,p,8f#,f#,8d#,f,8d#,2c',
    description: 'Spiderman theme',
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
    name: 'Tarzan',
    rtttl:
        'Tarzan:d=8,o=5,b=120:e,f,g,16c6,g,16c6,16g,16c6,g,4d6,g,g.,4c6,4p,f,g,a,16c6,a,16c6,16a,16c6,a,4d6,g,g.,4c6,4p,e,f,g,16c6,g,16c6,16g,16c6,g,4d6,g,g.,4c6,4p,f,g,a,16c6,a,16c6,16a,16c6,a,4d6,g,g.,4c6.',
    description: 'Tarzan Boy',
  ),
  RingtonePreset(
    name: 'Teletubbies',
    rtttl:
        'Tele Tubbies:d=4,o=5,b=125:16g.,p,16g,e,4g.,p,4a,2f.,16g.,p,16g,e,4g.,p,2d.,16g.,p,16g,e,4g.,p,4a,2f.,2g,2b,2c.6.',
    description: 'Teletubbies theme',
  ),
  RingtonePreset(
    name: 'Teenage Mutant Ninja Turtles',
    rtttl:
        'Teenage Turtles:d=8,o=6,b=100:g5,a5,g5,a5,g5,16a5,g.5,a5,a#5,c,a#5,c,a#5,16c,a#.5,c,d#,f,d#,f,d#,16f,d#.,f,16c,16c,16c,16c,a#5,4c,16c7,16c7,16c7',
    description: 'TMNT theme',
  ),
  RingtonePreset(
    name: 'The A Team',
    rtttl:
        'The A Team:d=8,o=5,b=132:4d#6,a#,2d#6,16p,g#,4a#,4d#.,p,16g,16a#,d#6,a#,f6,2d#6,16p,c#.6,16c6,16a#,g#.,2a#.',
    description: 'The A-Team theme',
  ),
  RingtonePreset(
    name: 'Thunderbirds',
    rtttl:
        'Thunder Birds:d=8,o=4,b=125:g#5,16f5,16g#5,4a#5,p,16d#5,16f5,g#5,a#5,d#6,16f6,16c6,d#6,f6,2a#5,g#5,16f5,16g#5,4a#5,p,16d#5,16f5,g#5,a#5,d#6,16f6,16c6,d#6,f6,2g6,g6,16a6,16e6,4g6,p,16e6,16d6,c6,b5,a.5,16b5,c6,e6,2d6,d#6,16f6,16c6,4d#6,p,16c6,16a#5,g#5,g5,f.5,16g5,g#5,a#5,c6,a#5,g5,d#5',
    description: 'Thunderbirds theme',
  ),
  RingtonePreset(
    name: 'Titanic',
    rtttl:
        'Titanic:d=8,o=6,b=120:c,d,2e.,d,c,d,g,2g,f,e,4c,2a5,g5,f5,16d5,16e5,2d5,p,c,d,2e.,d,c,d,g,2g,e,g,2a,2g,16d,16e,2d.',
    description: 'My Heart Will Go On',
  ),
  RingtonePreset(
    name: 'Toccata',
    rtttl:
        'Toccata:d=16,o=5,b=160:a,g,1a,g,f,e,d,2c#,p,2d,2p,a,g,1a,8e.,4f,2c#,2d',
    description: 'Toccata and Fugue',
  ),
  RingtonePreset(
    name: 'Transformers',
    rtttl:
        'Transformers:d=16,o=6,b=285:e7,f7,e7,d#7,4d7,4p,d,d,d,d,d,d,d,d,e,e,e,e,f,f,f,f,f,f,f,f,8a7,8a#7,8a7,8p,4d7,2p,d,d7,d,d7,d,d7,d,d7,e,e7,e,e7,f,f7,f,f7,f,f7,f,f7,a5,a5,a5,a5,a#5,a#,a#5,a#,a#5,a#,a#5,a#,a#5,a#,a#5,a#,4p,8d,8p,4e,4f,4p,4f,4p,2g,4a,4a#,4p,g,g7,g,g7,g,g7,g,g7,4e,4g,4a,4p,f,f7,f,f7,f,f7,f,f7,4e,4f,4g,4p,e,e7,e,e7,e,e7,e,e7,e,e7,e,e7,4p,4d,4c#,8e,8p,4d,2d,d,d7,d,d7,d,d7,d,d7',
    description: 'Transformers theme',
  ),
  RingtonePreset(
    name: 'Tubular Bells',
    rtttl:
        'Tubular Bells:d=4,o=5,b=280:c6,f6,c6,g6,c6,d#6,f6,c6,g#6,c6,a#6,c6,g6,g#6,c6,g6,c6,f6,c6,g6,c6,d#6,f6,c6,g#6,c6,a#6,c6,g6,g#6,c6,g6,c6,f6,c6,g6,c6,d#6,f6,c6,g#6,c6,a#6,c6,g6,g#6,c6,g6,c6,f6,c6,g6,c6,d#6,f6,c6,g#6,c6,a#6,c6,g6,g#6',
    description: 'Tubular Bells - Exorcist',
  ),
  RingtonePreset(
    name: 'Under the Sea',
    rtttl:
        'Under the Sea:d=4,o=6,b=200:8d,8f,8a#,d7,d7,8a#,c7,d#7,d7,a#,8a#5,8d,8f,a#,a#,8c,a,c7,a#,p,8d,8f,8a#,d7,d7,8a#,c7,d#7,d7,a#,8a#5,8d,8f,a#,a#,8c,a,c7,16a#,16d,16a#,16d,16a#,16d,16a#',
    description: 'Under the Sea - Little Mermaid',
  ),
  RingtonePreset(
    name: 'USA National Anthem',
    rtttl:
        'USA National Anthem:d=8,o=5,b=120:e.,d,4c,4e,4g,4c6.,p,e6.,d6,4c6,4e,4f#,4g.,p,4g,4e6.,d6,4c6,2b,a,4b,c6.,16p,4c6,4g,4e,32p,4c',
    description: 'Star-Spangled Banner',
  ),
  RingtonePreset(
    name: 'Wannabe',
    rtttl:
        'Wannabe:d=8,o=5,b=125:16g,16g,16g,16g,g,a,g,e,p,16c,16d,16c,d,d,c,4e,4p,g,g,g,a,g,e,p,4c6,c6,b,g,a,16b,16a,4g',
    description: 'Wannabe by Spice Girls',
  ),
  RingtonePreset(
    name: 'We Wish You a Merry Christmas',
    rtttl:
        'We Wish you a Merry Christmas:d=8,o=5,b=140:4d,4g,g,a,g,f#,4e,4c,4e,4a,a,b,a,g,4f#,4d,4f#,4b,b,c6,b,a,4g,4e,4d,4e,4a,4f#,2g',
    description: 'Merry Christmas carol',
  ),
  RingtonePreset(
    name: 'YMCA',
    rtttl:
        'YMCA:d=8,o=5,b=160:c#6,a#,2p,a#,g#,f#,g#,a#,4c#6,a#,4c#6,d#6,a#,2p,a#,g#,f#,g#,a#,4c#6,a#,4c#6,d#6,b,2p,b,a#,g#,a#,b,4d#6,f#6,4d#6,4f.6,4d#.6,4c#.6,4b.,4a#,4g#',
    description: 'YMCA by Village People',
  ),
];

/// Provider for custom ringtone presets stored in SharedPreferences
final customRingtonesProvider =
    StateNotifierProvider<CustomRingtonesNotifier, List<RingtonePreset>>((ref) {
      return CustomRingtonesNotifier();
    });

class CustomRingtonesNotifier extends StateNotifier<List<RingtonePreset>> {
  static const _prefsKey = 'custom_ringtones';

  CustomRingtonesNotifier() : super([]) {
    _loadPresets();
  }

  Future<void> _loadPresets() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_prefsKey) ?? [];

    final presets = <RingtonePreset>[];
    for (final item in saved) {
      final parts = item.split('|||');
      if (parts.length >= 2) {
        presets.add(
          RingtonePreset(
            name: parts[0],
            rtttl: parts[1],
            description: parts.length > 2 ? parts[2] : 'Custom ringtone',
          ),
        );
      }
    }
    state = presets;
  }

  Future<void> _savePresets() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = state
        .map((p) => '${p.name}|||${p.rtttl}|||${p.description}')
        .toList();
    await prefs.setStringList(_prefsKey, encoded);
  }

  Future<void> addPreset(RingtonePreset preset) async {
    state = [...state, preset];
    await _savePresets();
  }

  Future<void> removePreset(int index) async {
    final newState = [...state];
    newState.removeAt(index);
    state = newState;
    await _savePresets();
  }

  Future<void> updatePreset(int index, RingtonePreset preset) async {
    final newState = [...state];
    newState[index] = preset;
    state = newState;
    await _savePresets();
  }
}

class RingtoneScreen extends ConsumerStatefulWidget {
  const RingtoneScreen({super.key});

  @override
  ConsumerState<RingtoneScreen> createState() => _RingtoneScreenState();
}

class _RingtoneScreenState extends ConsumerState<RingtoneScreen> {
  final _rtttlController = TextEditingController();
  final _rtttlPlayer = RtttlPlayer();
  final _libraryService = RtttlLibraryService();
  bool _saving = false;
  bool _loading = false;
  bool _playing = false;
  int _selectedPresetIndex = -1;
  bool _showingCustom = false;
  int _playingPresetIndex = -1;
  bool _playingCustomPreset = false;
  String? _validationError;

  // Currently selected ringtone info (unified across all sources)
  String? _selectedName;
  String? _selectedDescription;
  String? _selectedSource; // 'library', 'builtin', 'custom'
  bool _playingSelected = false;
  int _libraryToneCount = 0; // Total tones in the library

  /// Maximum RTTTL string length supported by Meshtastic devices
  static const int _maxRtttlLength = 230;

  /// Validate RTTTL format
  /// Returns null if valid, error message if invalid
  String? _validateRtttl(String rtttl) {
    if (rtttl.trim().isEmpty) {
      return 'RTTTL string cannot be empty';
    }

    final trimmed = rtttl.trim();

    // Check length first
    if (trimmed.length > _maxRtttlLength) {
      return 'Too long: ${trimmed.length}/$_maxRtttlLength characters. Ringtone will be truncated.';
    }

    // Must have at least 2 colons (name:defaults:notes or defaults:notes)
    final colonCount = ':'.allMatches(trimmed).length;
    if (colonCount < 1) {
      return 'Invalid format: missing colons. Expected format: name:d=4,o=5,b=120:notes';
    }

    final parts = trimmed.split(':');

    // Get defaults section
    String defaults;
    String notesSection;

    if (parts.length >= 3) {
      defaults = parts[1].toLowerCase();
      notesSection = parts.sublist(2).join(':');
    } else if (parts.length == 2) {
      defaults = parts[0].toLowerCase();
      notesSection = parts[1];
    } else {
      return 'Invalid format: expected name:defaults:notes';
    }

    // Validate defaults section has proper key=value pairs
    bool hasValidDefaults = false;
    for (final part in defaults.split(',')) {
      final kv = part.trim().split('=');
      if (kv.length == 2) {
        final key = kv[0].trim();
        final value = kv[1].trim();
        if (['d', 'o', 'b'].contains(key) && int.tryParse(value) != null) {
          hasValidDefaults = true;
        }
      }
    }

    if (!hasValidDefaults) {
      return 'Invalid defaults: expected d=duration, o=octave, b=bpm';
    }

    // Validate notes section has valid note characters
    if (notesSection.trim().isEmpty) {
      return 'No notes found in RTTTL string';
    }

    // RTTTL note format: [duration]note[#][.][octave][.]
    // Duration: 1, 2, 4, 8, 16, 32, 64
    // Note: a-g or p (pause)
    // Optional sharp: #
    // Optional dot (can appear before OR after octave)
    // Octave: 4-7
    final validNotePattern = RegExp(
      r'^\d*[a-gp]#?\.?\d?\.?$',
      caseSensitive: false,
    );
    final notes = notesSection.split(',');

    for (final note in notes) {
      final trimmedNote = note.trim();
      if (trimmedNote.isEmpty) continue;
      if (!validNotePattern.hasMatch(trimmedNote)) {
        return 'Invalid note: "$trimmedNote". Notes should be like c, 8e6, f#, 4p';
      }
    }

    if (notes.where((n) => n.trim().isNotEmpty).isEmpty) {
      return 'No valid notes found';
    }

    return null; // Valid
  }

  void _onRtttlChanged(String value) {
    setState(() {
      _validationError = value.isEmpty ? null : _validateRtttl(value);
    });
  }

  @override
  void initState() {
    super.initState();
    _loadSavedRingtone();
    _rtttlController.addListener(() => _onRtttlChanged(_rtttlController.text));
  }

  @override
  void dispose() {
    _rtttlController.dispose();
    _rtttlPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadSavedRingtone() async {
    setState(() => _loading = true);
    try {
      // Load tone count
      final count = await _libraryService.getToneCount();

      final settings = await ref.read(settingsServiceProvider.future);
      final rtttl = settings.selectedRingtoneRtttl;
      final name = settings.selectedRingtoneName;

      if (mounted) {
        setState(() {
          _libraryToneCount = count;
          if (rtttl != null && name != null) {
            _rtttlController.text = rtttl;
            _selectedName = name;
            _selectedDescription = settings.selectedRingtoneDescription;
            _selectedSource = settings.selectedRingtoneSource;
          }
        });
      }
    } catch (e) {
      // Ignore - will use defaults
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveSelectedRingtone() async {
    if (_selectedName == null) return;

    try {
      final settings = await ref.read(settingsServiceProvider.future);
      await settings.setSelectedRingtone(
        rtttl: _rtttlController.text.trim(),
        name: _selectedName!,
        description: _selectedDescription,
        source: _selectedSource,
      );
    } catch (e) {
      // Ignore save errors
    }
  }

  Future<void> _playPreview() async {
    // Stop any preset playback
    if (_playingPresetIndex >= 0) {
      await _rtttlPlayer.stop();
      setState(() {
        _playingPresetIndex = -1;
        _playingCustomPreset = false;
      });
    }

    final validation = _validateRtttl(_rtttlController.text);
    if (validation != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validation),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_playing) {
      await _rtttlPlayer.stop();
      setState(() => _playing = false);
      return;
    }

    setState(() => _playing = true);

    try {
      await _rtttlPlayer.play(_rtttlController.text.trim());

      // Wait for playback to complete
      while (_rtttlPlayer.isPlaying) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (!mounted) break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to play: ${e.toString()}'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _playing = false);
      }
    }
  }

  Future<void> _playPreset(
    RingtonePreset preset,
    int index, {
    bool isCustom = false,
  }) async {
    // Stop main preview if playing
    if (_playing) {
      await _rtttlPlayer.stop();
      setState(() => _playing = false);
    }

    // If this preset is already playing, stop it
    if (_playingPresetIndex == index && _playingCustomPreset == isCustom) {
      await _rtttlPlayer.stop();
      setState(() {
        _playingPresetIndex = -1;
        _playingCustomPreset = false;
      });
      return;
    }

    // Stop any other preset
    if (_playingPresetIndex >= 0) {
      await _rtttlPlayer.stop();
    }

    setState(() {
      _playingPresetIndex = index;
      _playingCustomPreset = isCustom;
    });

    try {
      await _rtttlPlayer.play(preset.rtttl);

      // Wait for playback to complete
      while (_rtttlPlayer.isPlaying) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (!mounted) break;
      }
    } catch (e) {
      // Ignore errors during preset playback
    } finally {
      if (mounted) {
        setState(() {
          _playingPresetIndex = -1;
          _playingCustomPreset = false;
        });
      }
    }
  }

  Future<void> _playSelectedRingtone() async {
    if (_selectedName == null) return;

    // Stop main preview if playing
    if (_playing) {
      await _rtttlPlayer.stop();
      setState(() => _playing = false);
    }

    // Stop any preset if playing
    if (_playingPresetIndex >= 0) {
      await _rtttlPlayer.stop();
      setState(() {
        _playingPresetIndex = -1;
        _playingCustomPreset = false;
      });
    }

    // If selected item is already playing, stop it
    if (_playingSelected) {
      await _rtttlPlayer.stop();
      setState(() => _playingSelected = false);
      return;
    }

    setState(() => _playingSelected = true);

    try {
      await _rtttlPlayer.play(_rtttlController.text.trim());

      // Wait for playback to complete
      while (_rtttlPlayer.isPlaying) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (!mounted) break;
      }
    } catch (e) {
      // Ignore errors during playback
    } finally {
      if (mounted) {
        setState(() => _playingSelected = false);
      }
    }
  }

  Future<void> _saveRingtone() async {
    final validation = _validateRtttl(_rtttlController.text);
    if (validation != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validation),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final protocol = ref.read(protocolServiceProvider);
    setState(() => _saving = true);

    try {
      await protocol.setRingtone(_rtttlController.text.trim());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ringtone saved to device'),
            backgroundColor: AppTheme.darkCard,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save ringtone: $e'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _selectPreset(
    RingtonePreset preset,
    int index, {
    bool isCustom = false,
  }) {
    final source = isCustom ? 'custom' : 'builtin';
    setState(() {
      _rtttlController.text = preset.rtttl;
      _selectedPresetIndex = index;
      _showingCustom = isCustom;
      _validationError = null;
      // Update unified selection
      _selectedName = preset.name;
      _selectedDescription = preset.description;
      _selectedSource = source;
    });
    // Persist the selection
    _saveSelectedRingtone();
  }

  void _showAddCustomDialog() {
    AppBottomSheet.show(
      context: context,
      child: _AddCustomRingtoneContent(
        validateRtttl: _validateRtttl,
        onAdd: (preset) {
          ref.read(customRingtonesProvider.notifier).addPreset(preset);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Custom ringtone added'),
              backgroundColor: AppTheme.darkCard,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  void _showLibraryBrowser() {
    AppBottomSheet.showScrollable(
      context: context,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (scrollController) => _LibraryBrowserContent(
        scrollController: scrollController,
        libraryService: _libraryService,
        rtttlPlayer: _rtttlPlayer,
        onSelect: (item) {
          setState(() {
            _rtttlController.text = item.rtttl;
            _selectedPresetIndex = -1;
            _showingCustom = false;
            _validationError = null;
            // Update unified selection
            _selectedName = item.displayName;
            _selectedDescription = item.artist;
            _selectedSource = 'library';
          });
          // Persist the selection
          _saveSelectedRingtone();
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showRtttlHelp() {
    AppBottomSheet.showScrollable(
      context: context,
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'RTTTL Format Guide',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            _buildHelpSection(
              'What is RTTTL?',
              'Ring Tone Text Transfer Language (RTTTL) is a format for creating musical output with simple text strings.',
            ),
            _buildHelpSection('Format', 'name:d=duration,o=octave,b=bpm:notes'),
            _buildHelpSection(
              'Header',
              '• Name: Identifier (often ignored)\n'
                  '• d=N: Default note duration (1,2,4,8,16,32)\n'
                  '• o=N: Default octave (4,5,6,7)\n'
                  '• b=N: Beats per minute',
            ),
            _buildHelpSection(
              'Notes',
              '• c, c#, d, d#, e, f, f#, g, g#, a, a#, b\n'
                  '• p = pause/rest\n'
                  '• Optional duration prefix (4c = quarter note C)\n'
                  '• Optional octave suffix (c6 = C in octave 6)\n'
                  '• Optional dot for 1.5x duration (c.)',
            ),
            _buildHelpSection(
              'Example',
              '24:d=4,o=5,b=120:c,e,g,c6\n\n'
                  'Plays C, E, G, high C at 120 BPM\n'
                  'Default quarter notes in octave 5',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.graphBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.graphBlue.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.link,
                    color: AppTheme.graphBlue.withValues(alpha: 0.8),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Try Nokia Composer online to create and preview RTTTL strings',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,

              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customRingtones = ref.watch(customRingtonesProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: const Text(
          'Ringtone',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _showRtttlHelp,
            icon: const Icon(Icons.help_outline, color: AppTheme.textSecondary),
            tooltip: 'RTTTL Help',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _saving ? null : _saveRingtone,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryGreen,
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Current RTTTL input
                  const Text(
                    'RTTTL STRING',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textTertiary,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.darkCard,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _rtttlController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: 'Paste or select an RTTTL ringtone...',
                            hintStyle: TextStyle(
                              color: AppTheme.textTertiary.withValues(
                                alpha: 0.5,
                              ),
                              fontFamily: 'monospace',
                              fontSize: 13,
                            ),
                            filled: true,
                            fillColor: AppTheme.darkBackground,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: _validationError != null
                                  ? const BorderSide(
                                      color: AppTheme.errorRed,
                                      width: 1,
                                    )
                                  : BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: _validationError != null
                                  ? const BorderSide(
                                      color: AppTheme.errorRed,
                                      width: 1,
                                    )
                                  : BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: _validationError != null
                                    ? AppTheme.errorRed
                                    : AppTheme.primaryGreen,
                                width: 1,
                              ),
                            ),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                        if (_validationError != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 14,
                                color: AppTheme.errorRed,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _validationError!,
                                  style: const TextStyle(
                                    color: AppTheme.errorRed,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            // Play/Preview button
                            ElevatedButton.icon(
                              onPressed: _playPreview,
                              icon: Icon(
                                _playing ? Icons.stop : Icons.play_arrow,
                                size: 20,
                              ),
                              label: Text(_playing ? 'Stop' : 'Preview'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _playing
                                    ? AppTheme.errorRed
                                    : AppTheme.graphBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () {
                                _rtttlController.clear();
                                setState(() {
                                  _selectedPresetIndex = -1;
                                  _validationError = null;
                                });
                              },
                              icon: const Icon(Icons.clear, size: 16),
                              label: const Text('Clear'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.textSecondary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Tap Preview to hear, then Save to device',
                                style: TextStyle(
                                  color: AppTheme.textSecondary.withValues(
                                    alpha: 0.7,
                                  ),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Builder(
                              builder: (context) {
                                final len = _rtttlController.text.trim().length;
                                final isTooLong = len > _maxRtttlLength;
                                return Text(
                                  '$len/$_maxRtttlLength',
                                  style: TextStyle(
                                    color: isTooLong
                                        ? AppTheme.warningYellow
                                        : AppTheme.textTertiary,
                                    fontSize: 12,
                                    fontWeight: isTooLong
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Browse Library section
                  const Text(
                    'RINGTONE LIBRARY',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textTertiary,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _showLibraryBrowser,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.darkCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.graphBlue.withValues(alpha: 0.3),
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppTheme.graphBlue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.library_music,
                              color: AppTheme.graphBlue,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Browse ${_libraryToneCount > 0 ? '${(_libraryToneCount / 1000).toStringAsFixed(1).replaceAll('.0', '')}k+' : ''} Ringtones',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Search classic tunes, TV themes, movie soundtracks, and more',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary.withValues(
                                      alpha: 0.8,
                                    ),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward_ios,
                            color: AppTheme.graphBlue,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Selected ringtone section (unified across all sources)
                  if (_selectedName != null) ...[
                    const Text(
                      'SELECTED RINGTONE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textTertiary,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.darkCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            // Icon based on source
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _selectedSource == 'library'
                                    ? Icons.library_music
                                    : _selectedSource == 'custom'
                                    ? Icons.star
                                    : Icons.music_note,
                                color: AppTheme.primaryGreen,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Title and description
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedName!,
                                    style: const TextStyle(
                                      color: AppTheme.primaryGreen,
                                      fontWeight: FontWeight.w600,

                                      fontSize: 15,
                                    ),
                                  ),
                                  if (_selectedDescription != null)
                                    Text(
                                      _selectedDescription!,
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // Play button
                            GestureDetector(
                              onTap: () => _playSelectedRingtone(),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: _playingSelected
                                      ? AppTheme.primaryGreen.withValues(
                                          alpha: 0.15,
                                        )
                                      : AppTheme.darkBackground,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _playingSelected
                                      ? Icons.stop
                                      : Icons.play_arrow,
                                  color: _playingSelected
                                      ? AppTheme.primaryGreen
                                      : AppTheme.textSecondary,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Clear button
                            GestureDetector(
                              onTap: () async {
                                setState(() {
                                  _selectedName = null;
                                  _selectedDescription = null;
                                  _selectedSource = null;
                                  _selectedPresetIndex = -1;
                                  _showingCustom = false;
                                });
                                // Clear from persistent storage
                                try {
                                  final settings = await ref.read(
                                    settingsServiceProvider.future,
                                  );
                                  await settings.clearSelectedRingtone();
                                } catch (e) {
                                  // Ignore
                                }
                              },
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppTheme.darkBackground,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: AppTheme.textSecondary,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Built-in presets section
                  const Text(
                    'BUILT-IN PRESETS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textTertiary,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.darkCard,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: _builtInPresets.asMap().entries.map((entry) {
                        final index = entry.key;
                        final preset = entry.value;
                        final isSelected =
                            !_showingCustom && _selectedPresetIndex == index;
                        final isPlaying =
                            !_playingCustomPreset &&
                            _playingPresetIndex == index;

                        return Column(
                          children: [
                            InkWell(
                              onTap: () => _selectPreset(preset, index),
                              borderRadius: index == 0
                                  ? const BorderRadius.vertical(
                                      top: Radius.circular(12),
                                    )
                                  : index == _builtInPresets.length - 1
                                  ? const BorderRadius.vertical(
                                      bottom: Radius.circular(12),
                                    )
                                  : BorderRadius.zero,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    // Music icon
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppTheme.primaryGreen.withValues(
                                                alpha: 0.15,
                                              )
                                            : AppTheme.darkBackground,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        isSelected
                                            ? Icons.music_note
                                            : Icons.music_note_outlined,
                                        color: isSelected
                                            ? AppTheme.primaryGreen
                                            : AppTheme.textSecondary,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Title and description
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            preset.name,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? AppTheme.primaryGreen
                                                  : Colors.white,
                                              fontWeight: isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.w500,

                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            preset.description,
                                            style: const TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Play button
                                    SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: Material(
                                        color: isPlaying
                                            ? AppTheme.errorRed.withValues(
                                                alpha: 0.15,
                                              )
                                            : AppTheme.darkBackground,
                                        borderRadius: BorderRadius.circular(20),
                                        child: InkWell(
                                          onTap: () =>
                                              _playPreset(preset, index),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          child: Icon(
                                            isPlaying
                                                ? Icons.stop
                                                : Icons.play_arrow,
                                            color: isPlaying
                                                ? AppTheme.errorRed
                                                : AppTheme.textSecondary,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Selected indicator
                                    SizedBox(
                                      width: 24,
                                      child: isSelected
                                          ? const Icon(
                                              Icons.check_circle,
                                              color: AppTheme.primaryGreen,
                                              size: 22,
                                            )
                                          : const Icon(
                                              Icons.chevron_right,
                                              color: AppTheme.textTertiary,
                                              size: 22,
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (index < _builtInPresets.length - 1)
                              const Divider(
                                height: 1,
                                indent: 68,
                                color: AppTheme.darkBorder,
                              ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Custom presets section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'CUSTOM PRESETS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textTertiary,
                          letterSpacing: 1,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _showAddCustomDialog,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primaryGreen,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (customRingtones.isEmpty)
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.darkCard,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.library_music_outlined,
                            size: 48,
                            color: AppTheme.textTertiary.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No custom ringtones',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap "Add" to create your own presets',
                            style: TextStyle(
                              color: AppTheme.textTertiary.withValues(
                                alpha: 0.7,
                              ),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.darkCard,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: customRingtones.asMap().entries.map((
                            entry,
                          ) {
                            final index = entry.key;
                            final preset = entry.value;
                            final isSelected =
                                _showingCustom && _selectedPresetIndex == index;
                            final isPlaying =
                                _playingCustomPreset &&
                                _playingPresetIndex == index;
                            final isFirst = index == 0;
                            final isLast = index == customRingtones.length - 1;

                            return Column(
                              children: [
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _selectPreset(
                                      preset,
                                      index,
                                      isCustom: true,
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        left: 16,
                                        right: 16,
                                        top: isFirst ? 12 : 12,
                                        bottom: isLast ? 12 : 12,
                                      ),
                                      child: Row(
                                        children: [
                                          // Music icon
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? AppTheme.primaryMagenta
                                                        .withValues(alpha: 0.15)
                                                  : AppTheme.darkBackground,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              isSelected
                                                  ? Icons.music_note
                                                  : Icons.music_note_outlined,
                                              color: isSelected
                                                  ? AppTheme.primaryMagenta
                                                  : AppTheme.textSecondary,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          // Title and description
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  preset.name,
                                                  style: TextStyle(
                                                    color: isSelected
                                                        ? AppTheme
                                                              .primaryMagenta
                                                        : Colors.white,
                                                    fontWeight: isSelected
                                                        ? FontWeight.w600
                                                        : FontWeight.w500,

                                                    fontSize: 15,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  preset.description,
                                                  style: const TextStyle(
                                                    color:
                                                        AppTheme.textSecondary,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // Play button
                                          SizedBox(
                                            width: 40,
                                            height: 40,
                                            child: Material(
                                              color: isPlaying
                                                  ? AppTheme.errorRed
                                                        .withValues(alpha: 0.15)
                                                  : AppTheme.darkBackground,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              child: InkWell(
                                                onTap: () => _playPreset(
                                                  preset,
                                                  index,
                                                  isCustom: true,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                child: Icon(
                                                  isPlaying
                                                      ? Icons.stop
                                                      : Icons.play_arrow,
                                                  color: isPlaying
                                                      ? AppTheme.errorRed
                                                      : AppTheme.textSecondary,
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // Selected indicator
                                          SizedBox(
                                            width: 24,
                                            child: isSelected
                                                ? const Icon(
                                                    Icons.check_circle,
                                                    color:
                                                        AppTheme.primaryMagenta,
                                                    size: 22,
                                                  )
                                                : const Icon(
                                                    Icons.chevron_right,
                                                    color:
                                                        AppTheme.textTertiary,
                                                    size: 22,
                                                  ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                if (!isLast)
                                  const Divider(
                                    height: 1,
                                    indent: 68,
                                    color: AppTheme.darkBorder,
                                  ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Info card
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.warningYellow.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.warningYellow.withValues(alpha: 0.3),
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: AppTheme.warningYellow.withValues(alpha: 0.8),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tip: Find your device',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Send a message with the bell emoji (🔔) to trigger the ringtone on your device. Great for finding lost nodes!',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
      ),
    );
  }
}

class _AddCustomRingtoneContent extends StatefulWidget {
  final String? Function(String) validateRtttl;
  final void Function(RingtonePreset) onAdd;

  const _AddCustomRingtoneContent({
    required this.validateRtttl,
    required this.onAdd,
  });

  @override
  State<_AddCustomRingtoneContent> createState() =>
      _AddCustomRingtoneContentState();
}

class _AddCustomRingtoneContentState extends State<_AddCustomRingtoneContent> {
  final _nameController = TextEditingController();
  final _rtttlController = TextEditingController();
  final _descController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _rtttlController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }

    final validation = widget.validateRtttl(_rtttlController.text);
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }

    widget.onAdd(
      RingtonePreset(
        name: _nameController.text.trim(),
        rtttl: _rtttlController.text.trim(),
        description: _descController.text.trim().isEmpty
            ? 'Custom ringtone'
            : _descController.text.trim(),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BottomSheetHeader(
            title: 'Add Custom Ringtone',
            subtitle: 'Create a custom RTTTL ringtone preset',
          ),
          const SizedBox(height: 24),
          BottomSheetTextField(
            controller: _nameController,
            label: 'Name',
            hint: 'e.g., My Ringtone',
          ),
          const SizedBox(height: 16),
          BottomSheetTextField(
            controller: _rtttlController,
            label: 'RTTTL String',
            hint: '24:d=4,o=5,b=120:c,e,g',
            maxLines: 3,
            maxLength: 230,
            monospace: true,
            errorText: _error,
            onChanged: (value) {
              setState(() {
                _error = value.isEmpty ? null : widget.validateRtttl(value);
              });
            },
          ),
          const SizedBox(height: 16),
          BottomSheetTextField(
            controller: _descController,
            label: 'Description (optional)',
            hint: 'e.g., Classic beep melody',
          ),
          const SizedBox(height: 24),
          BottomSheetButtons(
            onCancel: () => Navigator.pop(context),
            onConfirm: _submit,
            confirmLabel: 'Add',
          ),
        ],
      ),
    );
  }
}

/// Library browser content for searching and selecting RTTTL ringtones
class _LibraryBrowserContent extends StatefulWidget {
  final ScrollController scrollController;
  final RtttlLibraryService libraryService;
  final RtttlPlayer rtttlPlayer;
  final void Function(RtttlLibraryItem) onSelect;

  const _LibraryBrowserContent({
    required this.scrollController,
    required this.libraryService,
    required this.rtttlPlayer,
    required this.onSelect,
  });

  @override
  State<_LibraryBrowserContent> createState() => _LibraryBrowserContentState();
}

class _LibraryBrowserContentState extends State<_LibraryBrowserContent> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  List<RtttlLibraryItem> _results = [];
  List<RtttlLibraryItem> _suggestions = [];
  bool _loading = false;
  bool _loadingSuggestions = true;
  String? _playingFilename;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    widget.rtttlPlayer.stop();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    final suggestions = await widget.libraryService.getSuggestions();
    final total = await widget.libraryService.getTotalCount();
    if (mounted) {
      setState(() {
        _suggestions = suggestions;
        _totalCount = total;
        _loadingSuggestions = false;
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);
    _performSearch(query);
  }

  Future<void> _performSearch(String query) async {
    final results = await widget.libraryService.search(query, limit: 50);
    if (mounted && _searchController.text.trim() == query) {
      setState(() {
        _results = results;
        _loading = false;
      });
    }
  }

  Future<void> _playItem(RtttlLibraryItem item) async {
    if (_playingFilename == item.filename) {
      await widget.rtttlPlayer.stop();
      setState(() => _playingFilename = null);
      return;
    }

    if (_playingFilename != null) {
      await widget.rtttlPlayer.stop();
    }

    setState(() => _playingFilename = item.filename);

    try {
      await widget.rtttlPlayer.play(item.rtttl);

      while (widget.rtttlPlayer.isPlaying) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (!mounted) break;
      }
    } catch (e) {
      // Ignore playback errors
    } finally {
      if (mounted) {
        setState(() => _playingFilename = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSearch = _searchController.text.trim().isNotEmpty;
    final displayList = hasSearch ? _results : _suggestions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ringtone Library',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _totalCount > 0
                    ? 'Search ${_totalCount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} available tones'
                    : 'Search thousands of available tones',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Search field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocus,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Search by song, artist, or theme...',
              hintStyle: TextStyle(
                color: AppTheme.textTertiary.withValues(alpha: 0.6),
                fontSize: 15,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: AppTheme.textSecondary,
                size: 22,
              ),
              suffixIcon: hasSearch
                  ? IconButton(
                      onPressed: () {
                        _searchController.clear();
                        _searchFocus.unfocus();
                      },
                      icon: const Icon(
                        Icons.clear,
                        color: AppTheme.textSecondary,
                        size: 20,
                      ),
                    )
                  : null,
              filled: true,
              fillColor: AppTheme.darkCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppTheme.graphBlue,
                  width: 1,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Results header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Text(
                hasSearch
                    ? '${_results.length} result${_results.length == 1 ? '' : 's'}'
                    : 'Popular Picks',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textTertiary,
                  letterSpacing: 1,
                ),
              ),
              if (_loading) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.graphBlue,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Results list
        Expanded(
          child: _loadingSuggestions && !hasSearch
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.graphBlue),
                )
              : displayList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasSearch
                            ? Icons.search_off
                            : Icons.library_music_outlined,
                        size: 48,
                        color: AppTheme.textTertiary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        hasSearch
                            ? 'No results found'
                            : 'Start typing to search',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      if (hasSearch) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Try a different search term',
                          style: TextStyle(
                            color: AppTheme.textTertiary.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              : ListView.builder(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: displayList.length,
                  itemBuilder: (context, index) {
                    final item = displayList[index];
                    final isPlaying = _playingFilename == item.filename;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.darkCard,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: () => widget.onSelect(item),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              // Music icon
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppTheme.graphBlue.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.music_note,
                                  color: AppTheme.graphBlue,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Title and subtitle
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.formattedTitle,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,

                                        fontSize: 15,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.subtitle ??
                                          '${item.rtttl.length} chars',
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Play button
                              SizedBox(
                                width: 40,
                                height: 40,
                                child: Material(
                                  color: isPlaying
                                      ? AppTheme.errorRed.withValues(
                                          alpha: 0.15,
                                        )
                                      : AppTheme.darkBackground,
                                  borderRadius: BorderRadius.circular(20),
                                  child: InkWell(
                                    onTap: () => _playItem(item),
                                    borderRadius: BorderRadius.circular(20),
                                    child: Icon(
                                      isPlaying ? Icons.stop : Icons.play_arrow,
                                      color: isPlaying
                                          ? AppTheme.errorRed
                                          : AppTheme.textSecondary,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              // Select indicator
                              const Icon(
                                Icons.chevron_right,
                                color: AppTheme.textTertiary,
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Bottom safe area
        const SizedBox(height: 16),
      ],
    );
  }
}
