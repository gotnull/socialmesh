# SocialMesh Translation Guide

This document is the complete reference for translating SocialMesh into new languages. It covers file structure, syntax rules, tooling, and workflow for both new and existing translators.

---

## Table of Contents

1. [Overview](#overview)
2. [File Structure](#file-structure)
3. [Current Translation Status](#current-translation-status)
4. [Getting Started](#getting-started)
5. [ARB File Format](#arb-file-format)
6. [Key Naming Conventions](#key-naming-conventions)
7. [Parameters and Placeholders](#parameters-and-placeholders)
8. [Plural Messages (ICU Syntax)](#plural-messages-icu-syntax)
9. [Things to Translate vs. Leave Alone](#things-to-translate-vs-leave-alone)
10. [Feature Areas](#feature-areas)
11. [Priority Order for Translation](#priority-order-for-translation)
12. [Testing Your Translation](#testing-your-translation)
13. [Validation and Quality Checks](#validation-and-quality-checks)
14. [Adding a New Language](#adding-a-new-language)
15. [Common Mistakes](#common-mistakes)
16. [Style Guide](#style-guide)
17. [Technical Reference](#technical-reference)

---

## Overview

SocialMesh uses Flutter's built-in `gen_l10n` internationalization system. All user-facing strings are stored in ARB (Application Resource Bundle) files -- JSON files with a specific structure.

- **English** (`app_en.arb`) is the template. It contains every key plus `@description` metadata.
- **Other locales** (`app_ru.arb`, `app_it.arb`, etc.) contain the same keys with translated values. No `@description` metadata is needed in translated files.
- Keys present in a locale file use that locale's value. Keys absent from a locale file fall back to English automatically.
- Keys present but with an **empty string** (`""`) will display blank in the app. Never leave a value empty.

The generated Dart code lives in `lib/l10n/` and is created automatically by `flutter gen-l10n`.

---

## File Structure

```
lib/l10n/
  app_en.arb              # English template (source of truth)
  app_ru.arb              # Russian translations
  app_it.arb              # Italian translations
  app_pt.arb              # Portuguese translations
  app_localizations.dart  # Generated (do not edit)
  app_localizations_en.dart
  app_localizations_ru.dart
  app_localizations_it.dart
  app_localizations_pt.dart
l10n.yaml                 # Configuration for gen_l10n
TRANSLATION_STATUS.md     # Auto-generated coverage report
```

**You only edit `app_<locale>.arb` files.** Everything else is generated.

---

## Current Translation Status

See [`TRANSLATION_STATUS.md`](../TRANSLATION_STATUS.md) for a live breakdown of
missing and untranslated keys per locale, grouped by feature area.

To regenerate it locally:

```
python3 scripts/check_translation_coverage.py
```

### How locale files work

Locale files only need to contain **keys you have actually translated**.
Any key missing from a locale file automatically falls back to the English
value at runtime — Flutter handles this natively. You do not need to copy
English placeholders into your locale file.

For example, a valid `app_ru.arb` with three translations:

```json
{
    "@@locale": "ru",
    "commonCancel": "Отмена",
    "commonSave": "Сохранить",
    "commonDelete": "Удалить"
}
```

All other keys display in English until translated.

---

## Getting Started

### For an existing language (ru, it, pt)

1. Run `python3 scripts/check_translation_coverage.py` to see which keys need translating.
2. Open `lib/l10n/app_en.arb` — this is the source of truth with all keys and English values.
3. Find a key you want to translate, then add it to your locale file (`lib/l10n/app_<locale>.arb`) with the translated value.
4. Save the file.
5. Run `flutter gen-l10n` to regenerate Dart code.
6. Test on a device or simulator set to that language.

Your locale file only needs keys you have actually translated. Do not copy
English values as placeholders — Flutter falls back to English automatically
for any missing key.

### Quick example

In `app_en.arb` (the template — do not edit):

```json
"commonSearch": "Search",
```

Add to `app_ru.arb` (your locale file):

```json
"commonSearch": "Поиск",
```

That is it. Copy the key from the English template, write the translated value.

---

## ARB File Format

Each ARB file is a JSON object. The only required special key is `@@locale`:

```json
{
  "@@locale": "ru",
  "keyName": "Translated text",
  "anotherKey": "More translated text"
}
```

### Rules

- The file must be valid JSON. A single misplaced comma or missing quote will break the build.
- Keys are **camelCase** identifiers (e.g., `commonSave`, `navigationMessages`).
- Values are strings. They may contain parameters in curly braces: `{name}`, `{count}`.
- Do **not** include `@description` metadata lines. Those only belong in `app_en.arb`.
- Do **not** change, add, or remove keys. The key set must match `app_en.arb` exactly.
- Do **not** change the `@@locale` value.
- Trailing commas are **not allowed** in JSON (unlike Dart).

---

## Key Naming Conventions

Keys follow this pattern: `<feature><Context><Element>`

| Prefix       | Feature area                | Example                                       |
| ------------ | --------------------------- | --------------------------------------------- |
| `common`     | Shared UI (buttons, labels) | `commonCancel`, `commonSave`                  |
| `navigation` | Drawer, bottom nav, tabs    | `navigationMessages`, `navigationMap`         |
| `settings`   | Settings screens            | `settingsThemeLabel`, `settingsNotifications` |
| `nodedex`    | NodeDex (node directory)    | `nodedexTraitBeacon`, `nodedexTagContact`     |
| `signal`     | Signals (posts)             | `signalCreateTitle`, `signalLikeButton`       |
| `channel`    | Messaging channels          | `channelNewTitle`, `channelDeleteConfirm`     |
| `device`     | Device management           | `deviceConnectButton`, `deviceBatteryLevel`   |
| `admin`      | Admin panel                 | `adminProductsAddTitle`                       |
| `aether`     | Aether flight tracking      | `aetherFlightStatus`                          |
| `tak`        | TAK integration             | `takGatewayTitle`                             |
| `help`       | Help and support            | `helpFaqTitle`                                |
| `auth`       | Authentication              | `authSignInButton`                            |
| `onboarding` | First-run experience        | `onboardingWelcomeTitle`                      |

This helps you locate related strings and translate them in batches.

---

## Parameters and Placeholders

Some strings contain parameters in curly braces. These are filled dynamically by the app. **You must keep them exactly as-is.**

### Simple parameters

```json
"navigationFirmwareMessage": "Firmware: {message}"
```

Translate the surrounding text but keep `{message}` intact:

```json
"navigationFirmwareMessage": "Прошивка: {message}"
```

### Multiple parameters

```json
"navigationFlightActivated": "{flightNumber} ({route}) is now airborne!"
```

You can reorder parameters to fit your language's grammar:

```json
"navigationFlightActivated": "Рейс {flightNumber} ({route}) в воздухе!"
```

### Common parameter names

| Parameter    | Contains              | Example              |
| ------------ | --------------------- | -------------------- |
| `{name}`     | A user or device name | "Hello, {name}"      |
| `{count}`    | A number              | "{count} messages"   |
| `{error}`    | An error message      | "Failed: {error}"    |
| `{distance}` | A distance value      | "{distance} km away" |
| `{date}`     | A formatted date      | "Created on {date}"  |
| `{message}`  | A dynamic message     | "Status: {message}"  |
| `{price}`    | A price value         | "${price}"           |

**Critical rule**: Never translate parameter names. `{name}` must remain `{name}`, not `{nombre}` or `{имя}`.

---

## Plural Messages (ICU Syntax)

Some strings use ICU MessageFormat for pluralization. These look more complex but follow a strict pattern:

```json
"aetherPickerResultCount": "{count, plural, =1{1 result} other{{count} results}}"
```

### Structure

```
{variable, plural, =0{zero form} =1{one form} other{many form}}
```

### Translation example

English:

```json
"authMfaDateMonthsAgo": "{count, plural, =1{1 month ago} other{{count} months ago}}"
```

Russian (which has more plural forms):

```json
"authMfaDateMonthsAgo": "{count, plural, =1{1 месяц назад} few{{count} месяца назад} many{{count} месяцев назад} other{{count} месяцев назад}}"
```

### Plural categories by language

| Category | When used        | Languages that need it       |
| -------- | ---------------- | ---------------------------- |
| `=0`     | Exactly zero     | Any (optional)               |
| `=1`     | Exactly one      | Any (optional)               |
| `=2`     | Exactly two      | Arabic                       |
| `one`    | Singular form    | Most languages               |
| `two`    | Dual form        | Arabic, Welsh                |
| `few`    | Small quantities | Russian, Polish, Czech       |
| `many`   | Large quantities | Russian, Polish, Arabic      |
| `other`  | Default/fallback | **Required in every plural** |

Russian needs `one`, `few`, `many`, and `other`. Italian needs `one` and `other`. English uses `=1` and `other`.

**Critical rule**: The `other` category is always required. Omitting it will crash the app.

---

## Things to Translate vs. Leave Alone

### Translate

- Button labels ("Save", "Cancel", "Delete")
- Screen titles ("Settings", "Messages")
- Descriptions and help text
- Error messages shown to users
- Navigation labels
- Tooltip text
- Empty state messages
- Confirmation dialogs

### Do NOT translate

- **Parameter names** in curly braces: `{name}`, `{count}`
- **Key names** (the left side of the colon): `"commonSave"`
- **Technical terms** that are product names: "Meshtastic", "MeshCore", "NodeDex", "Aether", "TAK", "MQTT", "BLE", "LoRa"
- **Brand names**: "SocialMesh", "IFTTT", "Firebase"
- **Unit abbreviations**: "dBm", "km", "MHz", "SNR"
- **ICU syntax keywords**: `plural`, `select`, `other`, `few`, `many`, `one`
- **The `@@locale` value**

### Use judgment

- "Mesh" as a standalone word -- generally keep as "Mesh" since it is a technical term
- "Node" -- can be translated if the language has a natural equivalent
- "Signal" -- context-dependent; it is both a technical term and a SocialMesh feature name. Translate as the SocialMesh feature (like a social media post), not the radio signal

---

## Feature Areas

The 8,675 keys are organized by feature. Here are the largest areas, roughly in order of user visibility:

| Prefix       | Keys | Description                                              |
| ------------ | ---- | -------------------------------------------------------- |
| `common`     | ~60  | Shared buttons, labels, actions (Cancel, Save, OK, etc.) |
| `navigation` | ~55  | Drawer menu, tab bar, navigation labels                  |
| `settings`   | ~292 | All settings screens                                     |
| `signal`     | ~224 | Signal creation, display, feeds                          |
| `social`     | ~436 | Social features (profiles, subscriptions)                |
| `nodedex`    | ~544 | Node directory, traits, sigils, explorer titles          |
| `device`     | ~271 | Device connection, management                            |
| `channel`    | ~163 | Channel messaging                                        |
| `node`       | ~262 | Node details, configuration                              |
| `map`        | ~106 | Map screen, markers, layers                              |
| `global`     | ~227 | Global/shared UI elements                                |
| `admin`      | ~522 | Admin panel (lower priority for general users)           |
| `widget`     | ~493 | Widget builder                                           |
| `automation` | ~337 | Automation engine                                        |
| `meshcore`   | ~326 | MeshCore protocol                                        |
| `help`       | ~424 | Help content and FAQ                                     |
| `aether`     | ~192 | Flight tracking                                          |
| `tak`        | ~178 | TAK gateway integration                                  |
| `telemetry`  | ~160 | Telemetry displays                                       |
| `account`    | ~115 | Account management                                       |
| `auth`       | ~110 | Authentication and sign-in                               |
| `file`       | ~112 | File transfers                                           |
| `premium`    | ~92  | Premium features and gating                              |
| `profile`    | ~83  | User profiles                                            |
| `incident`   | ~83  | Incident management                                      |
| `onboarding` | ~80  | First-run onboarding                                     |

---

## Priority Order for Translation

If you are starting fresh, translate in this order to maximize user impact:

### Priority 1 -- Core UI (est. ~200 keys)

1. `common*` -- buttons and actions every screen uses
2. `navigation*` -- drawer menu, tabs, bottom navigation
3. `onboarding*` -- first thing new users see
4. `auth*` -- sign-in and account creation
5. `settings*` (subset) -- main settings labels

### Priority 2 -- Primary Features (est. ~700 keys)

6. `signal*` -- signal creation and display
7. `channel*` -- messaging
8. `node*` and `nodedex*` (subset) -- node list and details
9. `device*` -- device connection and management
10. `map*` -- map screen

### Priority 3 -- Secondary Features (est. ~1,500 keys)

11. `social*` -- profiles, subscriptions
12. `account*` -- account management
13. `premium*` -- premium gating dialogs
14. `profile*` -- user profile editing
15. `global*` -- shared UI elements
16. `telemetry*` -- telemetry display

### Priority 4 -- Advanced Features (est. ~2,500 keys)

17. `meshcore*` -- MeshCore protocol screens
18. `automation*` -- automation engine
19. `widget*` -- widget builder
20. `aether*` -- flight tracking
21. `tak*` -- TAK integration
22. `incident*` -- incident management
23. `file*` -- file transfers

### Priority 5 -- Admin and Help (est. ~950 keys)

24. `admin*` -- admin panel (most users never see this)
25. `help*` -- help content and FAQ

---

## Testing Your Translation

### On iOS Simulator

1. Open the Simulator.
2. Go to Settings > General > Language & Region > Language.
3. Add your language and set it as primary.
4. Launch the app.

**Faster method** (no device language change): Edit the Xcode scheme:

- Product > Scheme > Edit Scheme > Run > Options > App Language > select your language.

### On Android Emulator

1. Open Settings > System > Languages & input > Languages.
2. Add your language and drag it to the top.
3. Launch the app.

### On a physical device

Change the device language in system settings. The app detects it automatically.

### What to check

- Strings display correctly (no blank text, no raw key names)
- Text does not overflow buttons or cards (some languages are longer than English)
- Parameters render correctly (e.g., "Hello, John" not "Hello, {name}")
- Plural forms work for your language (test with 0, 1, 2, 5, 21 items)
- Right-to-left (RTL) languages display correctly if applicable
- Special characters render (accents, Cyrillic, CJK, etc.)

---

## Validation and Quality Checks

### JSON validation

Before submitting, verify your ARB file is valid JSON:

```bash
python3 -c "import json; json.load(open('lib/l10n/app_ru.arb')); print('Valid JSON')"
```

### Regenerate and check for errors

```bash
flutter gen-l10n
```

This will fail if:

- A parameter placeholder is missing (e.g., English has `{name}` but your translation does not)
- ICU plural syntax is malformed
- JSON is invalid

It will **not** fail if your locale file is missing keys — Flutter falls back
to English for any key not present in your file.

### Check translation coverage

To see which keys still need translating:

```bash
python3 scripts/check_translation_coverage.py
```

This generates `TRANSLATION_STATUS.md` with a per-locale breakdown grouped by
feature area. CI runs this automatically on every push to `lib/l10n/`.

---

## Adding a New Language

To add a completely new language (e.g., German):

1. **Create a minimal ARB file**:

   ```json
   {
       "@@locale": "de"
   }
   ```

   Save as `lib/l10n/app_de.arb`. That is a valid starting point — every key
   falls back to English until you add a translation for it.

2. **Start translating**: Look at `app_en.arb` for the full key list. Add keys
   to your file one at a time or in batches, with translated values:

   ```json
   {
       "@@locale": "de",
       "commonCancel": "Abbrechen",
       "commonSave": "Speichern"
   }
   ```

3. **Do NOT copy** `app_en.arb` as a starting point. Your locale file should
   only contain keys you have actually translated. This keeps diffs clean and
   makes it obvious what still needs work.

   ```bash
   # See what needs translating
   python3 scripts/check_translation_coverage.py
   ```

4. **Register the locale**: With `gen_l10n`, any ARB file in `lib/l10n/` with
   a `@@locale` is auto-discovered. No code changes needed.

5. **Regenerate**: Run `flutter gen-l10n`. This creates `app_localizations_de.dart`.

6. **Translate keys** starting from Priority 1. Run the coverage script to track progress.

7. **Test** by switching the device language to German.

---

## Common Mistakes

### 1. Deleting or renaming a key

**Wrong:**

```json
"commonSave": "Сохранить",
"commonCancel_btn": "Отмена"     // <-- renamed key, will crash
```

**Right:**

```json
"commonSave": "Сохранить",
"commonCancel": "Отмена"
```

### 2. Removing a parameter

**Wrong:**

```json
"greetingMessage": "Hello!"      // <-- missing {name}
```

**Right:**

```json
"greetingMessage": "Привет, {name}!"
```

### 3. Translating a parameter name

**Wrong:**

```json
"greetingMessage": "Привет, {имя}!"   // <-- parameter renamed
```

**Right:**

```json
"greetingMessage": "Привет, {name}!"
```

### 4. Empty value

**Wrong:**

```json
"commonSave": ""     // <-- displays blank in the app
```

**Right:**

```json
"commonSave": "Сохранить"
```

If you have not translated it yet, leave the English text in place.

### 5. Trailing comma (invalid JSON)

**Wrong:**

```json
{
  "commonSave": "Сохранить",
  "commonCancel": "Отмена" // <-- trailing comma before }
}
```

**Right:**

```json
{
  "commonSave": "Сохранить",
  "commonCancel": "Отмена"
}
```

### 6. Broken ICU plural syntax

**Wrong:**

```json
"itemCount": "{count, plural, =1{1 item} {many items}}"    // <-- missing 'other' keyword
```

**Right:**

```json
"itemCount": "{count, plural, =1{1 item} other{{count} items}}"
```

### 7. Escaped or smart quotes

**Wrong:**

```json
"deleteConfirm": "Delete \u201Cthis item\u201D?"    // <-- Unicode escapes
```

**Right:**

```json
"deleteConfirm": "Удалить \"этот элемент\"?"
```

Use plain quotes. The ARB format handles UTF-8 natively.

---

## Style Guide

### General principles

- **Be concise.** Mobile screens are small. Shorter translations are usually better.
- **Be consistent.** Use the same word for the same concept everywhere. If "Save" is "Сохранить" in one place, it should be "Сохранить" everywhere.
- **Match formality.** SocialMesh uses informal but professional tone in English. Match that register in your language.
- **Preserve capitalization patterns.** If the English is in Title Case, use your language's equivalent convention. If it is sentence case, use sentence case.

### Technical terms

Keep these in English (or the accepted local form):

- Mesh, Node, BLE, LoRa, GPS, SNR, WiFi, USB, MQTT
- Meshtastic, MeshCore, NodeDex, Aether
- TAK, IFTTT, Firebase
- App-specific features: Signal (as in a SocialMesh post), Sigil, Explorer Title

### Tone

- Buttons: imperative ("Save", "Delete", "Retry")
- Error messages: informative and helpful, not blaming the user
- Empty states: encouraging ("No messages yet. Start a conversation!")
- Confirmations: clear about consequences ("This action cannot be undone.")

---

## Technical Reference

### How fallback works

Flutter's `gen_l10n` resolves strings in this order:

1. Exact locale match (e.g., `app_ru.arb` for Russian)
2. Language match without country (e.g., `app_pt.arb` for `pt_BR`)
3. Template locale (`app_en.arb`)

Since our locale files now contain all keys (with English placeholders for untranslated ones), fallback is effectively transparent. Users see English for untranslated strings regardless.

### Build command

```bash
flutter gen-l10n
```

This reads `l10n.yaml` and generates Dart classes from all ARB files. Run this after any ARB change.

### Configuration (l10n.yaml)

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-dir: lib/l10n
nullable-getter: false
```

`nullable-getter: false` means `AppLocalizations.of(context)` returns a non-nullable `AppLocalizations` -- it never returns null if delegates are configured correctly.

### Accessing strings in code

```dart
// In widgets (with BuildContext)
final l10n = context.l10n;
Text(l10n.commonSave);

// In non-widget code (context-free)
import 'dart:ui' show PlatformDispatcher;
import 'package:socialmesh/l10n/app_localizations.dart';

final l10n = lookupAppLocalizations(PlatformDispatcher.instance.locale);
print(l10n.commonSave);
```

Translators do not need to understand the Dart code, but this shows how the keys you translate end up in the UI.

### File encoding

All ARB files must be UTF-8 without BOM. Most editors default to this.

---

## Questions?

Open an issue on the SocialMesh repository or contact the maintainers. Include the locale code and the key name if you have a question about a specific string.
