#!/usr/bin/env python3
"""
Generate iOS launch screen images from HTML template.
Uses Playwright to capture screenshots at different iOS device sizes.

Usage:
    python scripts/generate_launch_screens.py
"""

import asyncio
import re
import sys
from pathlib import Path

try:
    from playwright.async_api import async_playwright
except ImportError:
    print("Playwright not installed. Installing...")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "playwright"])
    subprocess.check_call([sys.executable, "-m", "playwright", "install", "chromium"])
    from playwright.async_api import async_playwright


# iOS launch screen sizes (width x height)
IOS_SIZES = {
    "LaunchImage": (414, 896),      # 1x - iPhone XR/11
    "LaunchImage@2x": (828, 1792),  # 2x - iPhone XR/11
    "LaunchImage@3x": (1242, 2688), # 3x - iPhone XS Max/11 Pro Max
}

# Paths
SCRIPT_DIR = Path(__file__).parent
PROJECT_ROOT = SCRIPT_DIR.parent
HTML_FILE = PROJECT_ROOT / "assets" / "launch_screens" / "launch_screen.html"
PUBSPEC_FILE = PROJECT_ROOT / "pubspec.yaml"
OUTPUT_DIR = PROJECT_ROOT / "ios" / "Runner" / "Assets.xcassets" / "LaunchImage.imageset"


def get_version_from_pubspec() -> str:
    """Extract version from pubspec.yaml (without build number)."""
    content = PUBSPEC_FILE.read_text()
    match = re.search(r'^version:\s*(\d+\.\d+\.\d+)', content, re.MULTILINE)
    if match:
        return match.group(1)
    return "1.0.0"


def update_html_version(html_content: str, version: str) -> str:
    """Update version in HTML content."""
    return re.sub(
        r'Version \d+\.\d+\.\d+',
        f'Version {version}',
        html_content
    )


async def capture_screenshots():
    """Capture screenshots at all iOS sizes."""
    version = get_version_from_pubspec()
    print(f"📱 Generating launch screens for version {version}")
    
    # Read and update HTML
    html_content = HTML_FILE.read_text()
    html_content = update_html_version(html_content, version)
    
    # Write updated HTML to temp file
    temp_html = HTML_FILE.parent / "launch_screen_temp.html"
    temp_html.write_text(html_content)
    
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        
        for name, (width, height) in IOS_SIZES.items():
            print(f"  📸 Capturing {name} ({width}x{height})...")
            
            page = await browser.new_page(
                viewport={"width": width, "height": height},
                device_scale_factor=1,
            )
            
            await page.goto(f"file://{temp_html.absolute()}")
            
            # Wait for animations to settle
            await page.wait_for_timeout(1500)
            
            output_path = OUTPUT_DIR / f"{name}.png"
            await page.screenshot(path=str(output_path), type="png")
            
            await page.close()
            print(f"    ✅ Saved to {output_path.relative_to(PROJECT_ROOT)}")
        
        await browser.close()
    
    # Cleanup temp file
    temp_html.unlink()
    
    print(f"\n✨ Done! Generated {len(IOS_SIZES)} launch screen images.")


if __name__ == "__main__":
    asyncio.run(capture_screenshots())
