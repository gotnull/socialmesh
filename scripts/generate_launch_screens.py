#!/usr/bin/env python3
"""
Generate iOS launch screen images from HTML template.
Uses Playwright CLI to capture screenshots at different iOS device sizes.

Usage:
    python scripts/generate_launch_screens.py
"""

import re
import subprocess
import sys
from pathlib import Path


# iOS launch screen sizes (width x height)
IOS_SIZES = {
    "LaunchImage": (414, 896),       # 1x
    "LaunchImage@2x": (828, 1792),   # 2x
    "LaunchImage@3x": (1242, 2688),  # 3x
}

# Paths
SCRIPT_DIR = Path(__file__).parent
PROJECT_ROOT = SCRIPT_DIR.parent
HTML_FILE = PROJECT_ROOT / "assets" / "launch_screens" / "launch_screen.html"
PUBSPEC_FILE = PROJECT_ROOT / "pubspec.yaml"
OUTPUT_DIR = PROJECT_ROOT / "ios" / "Runner" / "Assets.xcassets" / "LaunchImage.imageset"


def get_version_from_pubspec() -> str:
    """Extract full version from pubspec.yaml (including build number)."""
    content = PUBSPEC_FILE.read_text()
    match = re.search(r'^version:\s*(\d+\.\d+\.\d+\+\d+)', content, re.MULTILINE)
    if match:
        return match.group(1)
    return "1.0.0"


def update_html_version(html_content: str, version: str) -> str:
    """Update version in HTML content."""
    return re.sub(
        r'Version [\d.+]+',
        f'Version {version}',
        html_content
    )


def capture_screenshots():
    """Capture screenshots at all iOS sizes using playwright CLI."""
    version = get_version_from_pubspec()
    print(f"📱 Generating launch screens for version {version}")
    
    # Read and update HTML with version
    html_content = HTML_FILE.read_text()
    html_content = update_html_version(html_content, version)
    
    # Write updated HTML to temp file
    temp_html = HTML_FILE.parent / "launch_screen_temp.html"
    temp_html.write_text(html_content)
    
    for name, (width, height) in IOS_SIZES.items():
        print(f"  📸 Capturing {name} ({width}x{height})...")
        
        output_path = OUTPUT_DIR / f"{name}.png"
        
        # Use playwright CLI to screenshot
        cmd = [
            "playwright", "screenshot",
            "--viewport-size", f"{width},{height}",
            "--wait-for-timeout", "3000",
            f"file://{temp_html.absolute()}",
            str(output_path)
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            print(f"    ❌ Error: {result.stderr}")
        else:
            print(f"    ✅ Saved to {output_path.relative_to(PROJECT_ROOT)}")
    
    # Cleanup temp file
    if temp_html.exists():
        temp_html.unlink()
    
    print(f"\n✨ Done! Generated {len(IOS_SIZES)} launch screen images.")


if __name__ == "__main__":
    capture_screenshots()
