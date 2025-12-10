"""Generate iOS and Android app icon variants from a single 1024x1024 source image.

Usage:
    python3 scripts/build_app_icons.py

Prerequisites:
    - macOS with the `sips` command available (installed by default)
    - Source image placed at assets/app_icons/source/socialmesh_icon_1024.png
    - Destination directory assets/app_icons/generated/ will be created automatically

The script resizes the source into all required iOS and Android icon sizes.
"""

from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
SOURCE_PATH = PROJECT_ROOT / "assets/app_icons/source/socialmesh_icon_v3_1024.png"
LAUNCH_SOURCE_PATH = PROJECT_ROOT / "assets/launch_screens/launchscreen.png"
OUTPUT_DIR = PROJECT_ROOT / "assets/app_icons/generated"
APP_ICONSET_PATH = PROJECT_ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
LAUNCH_IMAGESET_PATH = PROJECT_ROOT / "ios/Runner/Assets.xcassets/LaunchImage.imageset"

# Android mipmap directories and their required sizes
ANDROID_ICON_SPECS = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

ANDROID_RES_PATH = PROJECT_ROOT / "android/app/src/main/res"

ICON_SPECS = {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}

CONTENTS_JSON = {
    "images": [
        {"idiom": "iphone", "size": "20x20", "scale": "2x", "filename": "Icon-App-20x20@2x.png"},
        {"idiom": "iphone", "size": "20x20", "scale": "3x", "filename": "Icon-App-20x20@3x.png"},
        {"idiom": "iphone", "size": "29x29", "scale": "2x", "filename": "Icon-App-29x29@2x.png"},
        {"idiom": "iphone", "size": "29x29", "scale": "3x", "filename": "Icon-App-29x29@3x.png"},
        {"idiom": "iphone", "size": "40x40", "scale": "2x", "filename": "Icon-App-40x40@2x.png"},
        {"idiom": "iphone", "size": "40x40", "scale": "3x", "filename": "Icon-App-40x40@3x.png"},
        {"idiom": "iphone", "size": "60x60", "scale": "2x", "filename": "Icon-App-60x60@2x.png"},
        {"idiom": "iphone", "size": "60x60", "scale": "3x", "filename": "Icon-App-60x60@3x.png"},
        {"idiom": "ipad", "size": "20x20", "scale": "1x", "filename": "Icon-App-20x20@1x.png"},
        {"idiom": "ipad", "size": "20x20", "scale": "2x", "filename": "Icon-App-20x20@2x.png"},
        {"idiom": "ipad", "size": "29x29", "scale": "1x", "filename": "Icon-App-29x29@1x.png"},
        {"idiom": "ipad", "size": "29x29", "scale": "2x", "filename": "Icon-App-29x29@2x.png"},
        {"idiom": "ipad", "size": "40x40", "scale": "1x", "filename": "Icon-App-40x40@1x.png"},
        {"idiom": "ipad", "size": "40x40", "scale": "2x", "filename": "Icon-App-40x40@2x.png"},
        {"idiom": "ipad", "size": "76x76", "scale": "1x", "filename": "Icon-App-76x76@1x.png"},
        {"idiom": "ipad", "size": "76x76", "scale": "2x", "filename": "Icon-App-76x76@2x.png"},
        {"idiom": "ipad", "size": "83.5x83.5", "scale": "2x", "filename": "Icon-App-83.5x83.5@2x.png"},
        {"idiom": "ios-marketing", "size": "1024x1024", "scale": "1x", "filename": "Icon-App-1024x1024@1x.png"},
    ],
    "info": {"version": 1, "author": "xcode"},
}


def ensure_source_exists() -> None:
    if not SOURCE_PATH.exists():
        raise FileNotFoundError(
            f"Source icon not found at {SOURCE_PATH}. Please add the 1024x1024 PNG first."
        )


def generate_icons() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    for filename, size in ICON_SPECS.items():
        destination = OUTPUT_DIR / filename
        print(f"Generating {filename} ({size}x{size})")
        subprocess.run(
            [
                "sips",
                "-s",
                "format",
                "png",
                "-z",
                str(size),
                str(size),
                str(SOURCE_PATH),
                "--out",
                str(destination),
            ],
            check=True,
        )

    print(f"\nDone! Generated icons saved in {OUTPUT_DIR.resolve()}")


def sync_to_xcode_asset_catalog() -> None:
    APP_ICONSET_PATH.mkdir(parents=True, exist_ok=True)

    for filename in ICON_SPECS.keys():
        source = OUTPUT_DIR / filename
        if not source.exists():
            print(f"Warning: expected icon {filename} not found in {OUTPUT_DIR}")
            continue
        destination = APP_ICONSET_PATH / filename
        shutil.copy2(source, destination)

    contents_path = APP_ICONSET_PATH / "Contents.json"
    with contents_path.open("w", encoding="utf-8") as contents_file:
        json.dump(CONTENTS_JSON, contents_file, indent=2)
        contents_file.write("\n")

    print(f"AppIcon.appiconset updated at {APP_ICONSET_PATH.resolve()}")


def generate_android_icons() -> None:
    """Generate Android launcher icons in all mipmap densities."""
    print("\nGenerating Android icons...")
    
    for folder, size in ANDROID_ICON_SPECS.items():
        mipmap_dir = ANDROID_RES_PATH / folder
        mipmap_dir.mkdir(parents=True, exist_ok=True)
        
        destination = mipmap_dir / "ic_launcher.png"
        print(f"Generating {folder}/ic_launcher.png ({size}x{size})")
        subprocess.run(
            [
                "sips",
                "-s",
                "format",
                "png",
                "-z",
                str(size),
                str(size),
                str(SOURCE_PATH),
                "--out",
                str(destination),
            ],
            check=True,
        )
    
    print(f"\nAndroid icons updated in {ANDROID_RES_PATH.resolve()}")


def generate_launch_images() -> None:
    """Generate launch screen images for all iOS device sizes.
    
    iPhone 17 Pro Max: 1320x2868 (440x956 @3x)
    Using larger base sizes to support all modern iPhones.
    
    This function scales the source image to fill (maintaining aspect ratio)
    and crops to fit the target dimensions.
    """
    print("\nGenerating launch images...")
    
    if not LAUNCH_SOURCE_PATH.exists():
        print(f"Warning: Launch source image not found at {LAUNCH_SOURCE_PATH}")
        print("Skipping launch image generation. Please add a source image.")
        return
    
    # Launch image specs: filename -> (width, height)
    launch_specs = {
        "LaunchImage.png": (440, 956),
        "LaunchImage@2x.png": (880, 1912),
        "LaunchImage@3x.png": (1320, 2868),
    }
    
    LAUNCH_IMAGESET_PATH.mkdir(parents=True, exist_ok=True)
    
    for filename, (target_width, target_height) in launch_specs.items():
        destination = LAUNCH_IMAGESET_PATH / filename
        print(f"Generating {filename} ({target_width}x{target_height})")
        
        # Use ImageMagick to resize filling the area and crop from center
        subprocess.run(
            ["magick", str(LAUNCH_SOURCE_PATH), 
             "-resize", f"{target_width}x{target_height}^",
             "-gravity", "center",
             "-extent", f"{target_width}x{target_height}",
             str(destination)],
            check=True
        )
    
    # Update Contents.json
    launch_contents = {
        "images": [
            {"idiom": "universal", "filename": "LaunchImage.png", "scale": "1x"},
            {"idiom": "universal", "filename": "LaunchImage@2x.png", "scale": "2x"},
            {"idiom": "universal", "filename": "LaunchImage@3x.png", "scale": "3x"},
        ],
        "info": {"version": 1, "author": "xcode"},
    }
    
    contents_path = LAUNCH_IMAGESET_PATH / "Contents.json"
    with contents_path.open("w", encoding="utf-8") as f:
        json.dump(launch_contents, f, indent=2)
        f.write("\n")
    
    print(f"\nLaunch images updated at {LAUNCH_IMAGESET_PATH.resolve()}")


def main() -> None:
    ensure_source_exists()
    generate_icons()
    sync_to_xcode_asset_catalog()
    generate_android_icons()
    generate_launch_images()


if __name__ == "__main__":
    main()
