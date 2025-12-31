#!/usr/bin/env python3
"""
Generate iOS Launch Screen images with Socialmesh branding.

Requires: 
  pip install Pillow cairosvg

Usage:
  python generate_launch_images.py
"""

import os
import subprocess
import sys

# Check for required packages
try:
    from PIL import Image
    import cairosvg
except ImportError:
    print("Installing required packages...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "Pillow", "cairosvg"])
    from PIL import Image
    import cairosvg

# Output directory
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_DIR = os.path.join(SCRIPT_DIR, "..", "ios", "Runner", "Assets.xcassets", "LaunchImage.imageset")
SVG_PATH = os.path.join(SCRIPT_DIR, "launch_screens", "launch_screen.svg")

# iOS launch image sizes (using universal for all devices)
# 1x = 414x896 (iPhone XR/11 point size)
# 2x = 828x1792
# 3x = 1242x2688 (iPhone 14 Pro Max)
SIZES = {
    "LaunchImage.png": (414, 896),
    "LaunchImage@2x.png": (828, 1792),
    "LaunchImage@3x.png": (1242, 2688),
}

def generate_images():
    """Generate launch images from SVG at different scales."""
    
    if not os.path.exists(SVG_PATH):
        print(f"Error: SVG file not found at {SVG_PATH}")
        print("Please create the SVG first or update the path.")
        return False
    
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    for filename, (width, height) in SIZES.items():
        output_path = os.path.join(OUTPUT_DIR, filename)
        print(f"Generating {filename} ({width}x{height})...")
        
        try:
            # Convert SVG to PNG at specified size
            cairosvg.svg2png(
                url=SVG_PATH,
                write_to=output_path,
                output_width=width,
                output_height=height,
            )
            print(f"  ✓ Saved to {output_path}")
        except Exception as e:
            print(f"  ✗ Error: {e}")
            return False
    
    print("\n✅ All launch images generated successfully!")
    print(f"   Output directory: {OUTPUT_DIR}")
    return True

if __name__ == "__main__":
    success = generate_images()
    sys.exit(0 if success else 1)
