#!/usr/bin/env python3
"""
Build RTTTL JSON database from individual tone files.

This script scans the assets/rtttl directory and compiles all valid RTTTL
tones into a single JSON file for efficient loading.
"""

import json
import os
import re
from pathlib import Path


# Character replacements for fixing encoding issues
CHAR_REPLACEMENTS = {
    '\u201a': ',',  # ‚ (single low-9 quotation mark) -> comma
    '\u00a0': ' ',  # Non-breaking space -> regular space
    '\u2018': "'",  # ' (left single quote) -> apostrophe
    '\u2019': "'",  # ' (right single quote) -> apostrophe
    '\u201c': '"',  # " (left double quote) -> quote
    '\u201d': '"',  # " (right double quote) -> quote
    '\u2013': '-',  # – (en dash) -> hyphen
    '\u2014': '-',  # — (em dash) -> hyphen
    '\u2026': '...', # … (ellipsis) -> three dots
    '\u00b4': "'",  # ´ (acute accent) -> apostrophe
    '\u0060': "'",  # ` (grave accent) -> apostrophe
    '\ufeff': '',   # BOM -> remove
    '\u200b': '',   # Zero-width space -> remove
    '\u200c': '',   # Zero-width non-joiner -> remove
    '\u200d': '',   # Zero-width joiner -> remove
    '\ufffd': '',   # Replacement character -> remove
}


def clean_string(s: str) -> str:
    """Clean a string by replacing problematic characters."""
    for old, new in CHAR_REPLACEMENTS.items():
        s = s.replace(old, new)
    # Remove any other non-ASCII non-printable characters
    s = ''.join(c if c.isprintable() or c in '\n\r\t' else '' for c in s)
    return s


# Built-in presets that should always be included
BUILTIN_PRESETS = [
    {
        'filename': '_builtin_meshtastic_default',
        'displayName': 'Meshtastic Default',
        'toneName': '24',
        'artist': 'Meshtastic',
        'rtttl': '24:d=32,o=5,b=565:f6,p,f6,4p,p,f6,p,f6,2p,p,b6,p,b6,p,b6,p,b6,p,b,p,b,p,b,p,b,p,b,p,b,p,b,p,b,1p.,2p.,p',
        'builtin': True,
    },
    {
        'filename': '_builtin_nokia',
        'displayName': 'Nokia Ringtone',
        'toneName': '24',
        'artist': 'Nokia',
        'rtttl': '24:d=4,o=5,b=180:8e6,8d6,f#,g#,8c#6,8b,d,e,8b,8a,c#,e,2a',
        'builtin': True,
    },
    {
        'filename': '_builtin_zelda',
        'displayName': 'Zelda Get Item',
        'toneName': '24',
        'artist': 'Nintendo',
        'rtttl': '24:d=16,o=5,b=120:g,c6,d6,2g6',
        'builtin': True,
    },
    {
        'filename': '_builtin_mario_coin',
        'displayName': 'Mario Coin',
        'toneName': '24',
        'artist': 'Nintendo',
        'rtttl': '24:d=8,o=6,b=200:b,e7',
        'builtin': True,
    },
    {
        'filename': '_builtin_mario_powerup',
        'displayName': 'Mario Power Up',
        'toneName': 'powerup',
        'artist': 'Nintendo',
        'rtttl': 'powerup:d=16,o=5,b=200:g,a,b,c6,d6,e6,f#6,g6,a6,b6,2c7',
        'builtin': True,
    },
    {
        'filename': '_builtin_mario_theme',
        'displayName': 'Mario Theme',
        'toneName': '24',
        'artist': 'Nintendo',
        'rtttl': '24:d=4,o=5,b=100:16e6,16e6,32p,8e6,16c6,8e6,8g6,8p,8g',
        'builtin': True,
    },
    {
        'filename': '_builtin_morse_cq',
        'displayName': 'Morse CQ',
        'toneName': '24',
        'artist': None,
        'rtttl': '24:d=16,o=6,b=120:8c,p,c,p,8c,p,c,4p,8c,p,8c,p,c,p,8c,8p',
        'builtin': True,
    },
    {
        'filename': '_builtin_simple_beep',
        'displayName': 'Simple Beep',
        'toneName': '24',
        'artist': None,
        'rtttl': '24:d=4,o=5,b=120:c6,p,c6',
        'builtin': True,
    },
    {
        'filename': '_builtin_alert',
        'displayName': 'Alert',
        'toneName': '24',
        'artist': None,
        'rtttl': '24:d=8,o=6,b=140:c,e,g,c7,p,c7,g,e,c',
        'builtin': True,
    },
    {
        'filename': '_builtin_ping',
        'displayName': 'Ping',
        'toneName': '24',
        'artist': None,
        'rtttl': '24:d=16,o=6,b=200:e,p,e',
        'builtin': True,
    },
    {
        'filename': '_builtin_pager',
        'displayName': 'Pager',
        'toneName': 'Pager',
        'artist': None,
        'rtttl': 'Pager:d=8,o=5,b=160:d6,16p,2d6,16p,d6,16p,2d6,16p,d6,16p,2d6.',
        'builtin': True,
    },
]


def parse_rtttl_file(filepath: Path) -> dict | None:
    """Parse an RTTTL file and extract the tone data."""
    try:
        content = filepath.read_text(encoding='utf-8', errors='ignore').strip()
    except Exception as e:
        print(f"  Error reading {filepath.name}: {e}")
        return None

    if not content:
        return None

    # Clean the content
    content = clean_string(content)

    # Find the actual RTTTL line (skip comments)
    rtttl_line = None
    for line in content.split('\n'):
        line = line.strip()
        if not line:
            continue
        # Skip common comment formats
        if line.startswith('//') or line.startswith('#') or line.startswith("'"):
            continue
        # Valid RTTTL must have at least one colon
        if ':' in line:
            rtttl_line = line
            break

    if not rtttl_line:
        return None

    # Extract tone name from RTTTL (part before first colon)
    colon_idx = rtttl_line.find(':')
    tone_name = rtttl_line[:colon_idx].strip() if colon_idx > 0 else ''

    # Parse filename for display name and artist
    filename = filepath.stem  # Remove extension
    filename = clean_string(filename)  # Clean any bad chars in filename
    display_name = filename
    artist = None

    # Try to extract artist from "Artist - Song" format
    if ' - ' in filename:
        parts = filename.split(' - ', 1)
        if len(parts) == 2:
            artist = parts[0].strip()
            display_name = parts[1].strip()

    return {
        'filename': filepath.name,
        'displayName': display_name,
        'toneName': tone_name,
        'artist': artist,
        'rtttl': rtttl_line,
    }


def main():
    # Paths
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    rtttl_dir = project_root / 'assets' / 'rtttl'
    output_file = project_root / 'assets' / 'rtttl_library.json'

    if not rtttl_dir.exists():
        print(f"Error: RTTTL directory not found: {rtttl_dir}")
        return 1

    print(f"Scanning {rtttl_dir}...")

    # Collect all tones
    tones = []
    skipped = 0
    errors = 0

    # Process .txt files (valid RTTTL format)
    txt_files = list(rtttl_dir.glob('*.txt'))
    print(f"Found {len(txt_files)} .txt files")

    for filepath in sorted(txt_files):
        result = parse_rtttl_file(filepath)
        if result:
            tones.append(result)
        else:
            skipped += 1

    # Process .bas files (check if they contain valid RTTTL)
    bas_files = list(rtttl_dir.glob('*.bas'))
    print(f"Found {len(bas_files)} .bas files")

    for filepath in sorted(bas_files):
        result = parse_rtttl_file(filepath)
        if result:
            # Only include if it looks like valid RTTTL (not binary/hex data)
            rtttl = result['rtttl']
            # Valid RTTTL should have note letters and comma-separated values
            if re.search(r'[a-gp]', rtttl, re.IGNORECASE) and ',' in rtttl:
                tones.append(result)
            else:
                skipped += 1
        else:
            skipped += 1

    # Sort by display name
    tones.sort(key=lambda x: x['displayName'].lower())

    # Deduplicate by RTTTL content (keep the one with the best/shortest name)
    seen_rtttl = {}
    for tone in tones:
        rtttl = tone['rtttl'].strip()
        if rtttl not in seen_rtttl:
            seen_rtttl[rtttl] = tone
        else:
            # Keep the one with shorter/cleaner name (less likely to have version suffix)
            existing = seen_rtttl[rtttl]
            existing_name = existing['displayName']
            new_name = tone['displayName']
            # Prefer names without version indicators (V2, v2, 2, etc.)
            existing_has_version = bool(re.search(r'[vV]?\d+$', existing_name))
            new_has_version = bool(re.search(r'[vV]?\d+$', new_name))
            if existing_has_version and not new_has_version:
                seen_rtttl[rtttl] = tone
            elif not existing_has_version and new_has_version:
                pass  # Keep existing
            elif len(new_name) < len(existing_name):
                seen_rtttl[rtttl] = tone
    
    tones = list(seen_rtttl.values())
    
    # Second pass: deduplicate by normalized display name
    # This catches "Indiana Jones" vs "IndianaJones", "Super Mario" vs "SuperMario", etc.
    def normalize_name(name: str) -> str:
        """Normalize a name for deduplication - lowercase, no spaces, no special chars."""
        # Remove common suffixes/prefixes that indicate variations
        name = re.sub(r'\s*[\(\[].*?[\)\]]', '', name)  # Remove (variations) and [variations]
        name = re.sub(r'\s*[-_]\s*\d+$', '', name)  # Remove trailing -1, _2, etc.
        name = re.sub(r'\s*[vV]\d+$', '', name)  # Remove trailing v1, V2, etc.
        # Normalize: lowercase, remove all non-alphanumeric
        return re.sub(r'[^a-z0-9]', '', name.lower())
    
    seen_names = {}
    for tone in tones:
        normalized = normalize_name(tone['displayName'])
        if normalized not in seen_names:
            seen_names[normalized] = tone
        else:
            # Keep the one with the shortest RTTTL (simpler/cleaner version)
            existing = seen_names[normalized]
            existing_rtttl_len = len(existing['rtttl'])
            new_rtttl_len = len(tone['rtttl'])
            # Prefer shorter RTTTL (simpler version)
            if new_rtttl_len < existing_rtttl_len:
                seen_names[normalized] = tone
            # If same length, prefer name with proper spacing (looks cleaner)
            elif new_rtttl_len == existing_rtttl_len:
                existing_has_spaces = ' ' in existing['displayName']
                new_has_spaces = ' ' in tone['displayName']
                if new_has_spaces and not existing_has_spaces:
                    seen_names[normalized] = tone
    
    tones = list(seen_names.values())
    tones.sort(key=lambda x: x['displayName'].lower())

    # Add built-in presets at the beginning
    # Meshtastic Default is first, then other built-ins, then the rest
    builtin_tones = list(BUILTIN_PRESETS)
    
    # Remove any duplicates from the main list that match built-in names
    builtin_names = {t['displayName'].lower() for t in builtin_tones}
    tones = [t for t in tones if t['displayName'].lower() not in builtin_names]
    
    # Combine: built-ins first, then sorted library
    all_tones = builtin_tones + tones

    # Build output
    output = {
        'version': 1,
        'tones': all_tones,
    }

    # Write JSON file
    print(f"\nWriting {len(tones)} tones to {output_file}...")
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(output, f, indent=2, ensure_ascii=False)

    file_size = output_file.stat().st_size
    print(f"Done! Output file size: {file_size:,} bytes ({file_size / 1024 / 1024:.2f} MB)")
    print(f"Skipped {skipped} invalid files")

    return 0


if __name__ == '__main__':
    exit(main())
