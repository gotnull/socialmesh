#!/usr/bin/env python3
"""
Generate Play Store Feature Graphic PNG from HTML template.
Uses Playwright CLI to capture a screenshot at exactly 1024x500.

Usage:
    python marketing/play-feature-graphic/render.py
    
Requirements:
    pip install playwright
    playwright install chromium
"""

import subprocess
from pathlib import Path


# Paths
SCRIPT_DIR = Path(__file__).parent
PROJECT_ROOT = SCRIPT_DIR.parent.parent
HTML_FILE = SCRIPT_DIR / "index.html"
OUTPUT_FILE = SCRIPT_DIR / "feature-graphic-1024x500.png"


def capture_screenshot():
    """Capture the feature graphic at 1024x500."""
    print("🎨 Generating Play Store Feature Graphic...")
    print(f"   Source: {HTML_FILE.relative_to(PROJECT_ROOT)}")
    print(f"   Output: {OUTPUT_FILE.relative_to(PROJECT_ROOT)}")
    
    # Use playwright CLI to screenshot at exact dimensions
    cmd = [
        "playwright", "screenshot",
        "--viewport-size", "1024,500",
        "--wait-for-timeout", "2000",
        f"file://{HTML_FILE.absolute()}",
        str(OUTPUT_FILE)
    ]
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    
    if result.returncode != 0:
        print(f"❌ Error: {result.stderr}")
        return False
    
    # Verify dimensions
    try:
        from PIL import Image
        with Image.open(OUTPUT_FILE) as img:
            width, height = img.size
            if width == 1024 and height == 500:
                print(f"✅ Success! Generated {width}x{height} PNG")
            else:
                print(f"⚠️  Warning: Image is {width}x{height}, expected 1024x500")
    except ImportError:
        print(f"✅ Screenshot saved (install Pillow to verify dimensions)")
    
    print(f"\n📁 Output: {OUTPUT_FILE}")
    return True


if __name__ == "__main__":
    capture_screenshot()
