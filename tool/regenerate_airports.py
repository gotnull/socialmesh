#!/usr/bin/env python3
"""Regenerate airports.dart with lat/lon from OurAirports CSV.

Downloads the latest OurAirports airports.csv (CC0 Public Domain),
filters to large_airport type with valid IATA codes, and overwrites
the kAirports const list in airports.dart while preserving the class
definition and lookup code at the top and bottom of the file.
"""

import csv
import io
import urllib.request

CSV_URL = "https://davidmegginson.github.io/ourairports-data/airports.csv"
OUTPUT = "lib/features/aether/data/airports.dart"


def fetch_airports():
    """Fetch and parse OurAirports CSV, return large airports with IATA codes."""
    print(f"Fetching {CSV_URL} ...")
    with urllib.request.urlopen(CSV_URL) as resp:
        raw = resp.read().decode("utf-8")
    reader = csv.DictReader(io.StringIO(raw))
    airports = []
    for row in reader:
        if row["type"] != "large_airport":
            continue
        iata = (row.get("iata_code") or "").strip()
        if not iata or len(iata) < 2:
            continue
        icao = (row.get("ident") or "").strip()
        name = (row.get("name") or "").strip()
        # Clean up common suffixes for brevity
        for suffix in [" International Airport", " Airport"]:
            if name.endswith(suffix):
                name = name[: -len(suffix)]
        name = name.replace(" / ", " / ").strip()
        city = (row.get("municipality") or "").strip() or name
        country = (row.get("iso_country") or "").strip()
        lat = float(row.get("latitude_deg") or 0)
        lon = float(row.get("longitude_deg") or 0)
        airports.append(
            {
                "iata": iata,
                "icao": icao,
                "name": name,
                "city": city,
                "country": country,
                "latitude": lat,
                "longitude": lon,
            }
        )
    airports.sort(key=lambda a: a["iata"])
    print(f"Found {len(airports)} large airports with IATA codes")
    return airports


def escape_dart(s):
    return s.replace("\\", "\\\\").replace("'", "\\'")


def generate_dart(airports):
    """Read existing airports.dart, replace just the kAirports list."""
    # Read existing file to get header (class def) and footer (lookup maps)
    with open(OUTPUT, "r") as f:
        content = f.read()

    # Find the start of the kAirports list
    list_start_marker = "const List<Airport> kAirports = ["
    list_start = content.find(list_start_marker)
    if list_start == -1:
        raise ValueError(f"Could not find '{list_start_marker}' in {OUTPUT}")

    # Find everything before that line (including the doc comment)
    # Go back to find the doc comment
    doc_comment_start = content.rfind("///", 0, list_start)
    if doc_comment_start == -1:
        doc_comment_start = list_start
    # Go back to the start of the line
    doc_comment_start = content.rfind("\n", 0, doc_comment_start) + 1

    header = content[:doc_comment_start]

    # Find the end of the list ("];")
    list_end = content.find("];", list_start)
    if list_end == -1:
        raise ValueError("Could not find end of kAirports list")
    list_end += 2  # include "];"

    footer = content[list_end:]

    # Build new list
    lines = []
    lines.append(
        f"/// All large airports worldwide (OurAirports, CC0 Public Domain)."
    )
    lines.append("///")
    lines.append(
        f"/// Sorted alphabetically by IATA code. This list is generated from the"
    )
    lines.append(
        f"/// OurAirports open dataset (https://ourairports.com/data/) filtered to"
    )
    lines.append(f"/// airports classified as 'large_airport' ({len(airports)} total).")
    lines.append("const List<Airport> kAirports = [")
    for a in airports:
        lines.append("  Airport(")
        lines.append(f"    iata: '{escape_dart(a['iata'])}',")
        lines.append(f"    icao: '{escape_dart(a['icao'])}',")
        lines.append(f"    name: '{escape_dart(a['name'])}',")
        lines.append(f"    city: '{escape_dart(a['city'])}',")
        lines.append(f"    country: '{escape_dart(a['country'])}',")
        lines.append(f"    latitude: {a['latitude']},")
        lines.append(f"    longitude: {a['longitude']},")
        lines.append("  ),")
    lines.append("];")

    with open(OUTPUT, "w") as f:
        f.write(header)
        f.write("\n".join(lines))
        f.write(footer)

    total_lines = (header + "\n".join(lines) + footer).count("\n") + 1
    print(f"Wrote {OUTPUT} ({total_lines} lines, {len(airports)} airports)")


if __name__ == "__main__":
    airports = fetch_airports()
    generate_dart(airports)
