#!/usr/bin/env python3
"""
Update AppIcon.appiconset/Contents.json to reference icon files.

Usage: python3 scripts/update-appicon-contents.py <appicon_dir> [icons_dir]
"""
import json
import sys
from pathlib import Path


def update_contents_json(appicon_dir: str, icons_dir: str = None) -> bool:
    """
    Update Contents.json to reference icon files.
    
    Args:
        appicon_dir: Path to AppIcon.appiconset directory
        icons_dir: Optional path to icons directory (for validation)
    
    Returns:
        True if successful, False otherwise
    """
    contents_json = Path(appicon_dir) / "Contents.json"
    if not contents_json.exists():
        print(f"  ❌ Contents.json not found at {contents_json}")
        return False
    
    with open(contents_json, 'r') as f:
        contents = json.load(f)
    
    # Map of size/scale to filename
    icon_map = {
        ("16", "1x"): "icon_16x16.png",
        ("16", "2x"): "icon_16x16@2x.png",
        ("32", "1x"): "icon_32x32.png",
        ("32", "2x"): "icon_32x32@2x.png",
        ("128", "1x"): "icon_128x128.png",
        ("128", "2x"): "icon_128x128@2x.png",
        ("256", "1x"): "icon_256x256.png",
        ("256", "2x"): "icon_256x256@2x.png",
        ("512", "1x"): "icon_512x512.png",
        ("512", "2x"): "icon_512x512@2x.png",
        ("1024", None): "AppIcon_1024x1024.png",  # iOS
    }
    
    # Update images array
    for image in contents.get("images", []):
        size = image.get("size", "")
        scale = image.get("scale")
        idiom = image.get("idiom", "")
        
        if idiom == "mac":
            key = (size.split("x")[0], scale)
            if key in icon_map:
                filename = icon_map[key]
                if (Path(appicon_dir) / filename).exists():
                    image["filename"] = filename
        elif idiom == "universal" or idiom == "ios":
            if size == "1024x1024":
                filename = icon_map[("1024", None)]
                if (Path(appicon_dir) / filename).exists():
                    image["filename"] = filename
    
    with open(contents_json, 'w') as f:
        json.dump(contents, f, indent=2)
        f.write("\n")
    
    print("  ✅ Contents.json updated")
    return True


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 update-appicon-contents.py <appicon_dir> [icons_dir]")
        sys.exit(1)
    
    appicon_dir = sys.argv[1]
    icons_dir = sys.argv[2] if len(sys.argv) > 2 else None
    
    success = update_contents_json(appicon_dir, icons_dir)
    sys.exit(0 if success else 1)

