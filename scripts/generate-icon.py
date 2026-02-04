#!/usr/bin/env python3
"""Generate app icon for Project Launcher"""

import subprocess
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)
ICON_DIR = os.path.join(PROJECT_DIR, "macos/Runner/Assets.xcassets/AppIcon.appiconset")

# Icon sizes needed for macOS
SIZES = [16, 32, 64, 128, 256, 512, 1024]

def create_icon_svg():
    """Create SVG icon"""
    svg = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#4F46E5"/>
      <stop offset="100%" style="stop-color:#7C3AED"/>
    </linearGradient>
  </defs>
  <rect width="1024" height="1024" rx="220" fill="url(#bg)"/>
  <g transform="translate(200, 200)">
    <!-- Folder icon -->
    <path d="M0 120 L0 520 Q0 560 40 560 L584 560 Q624 560 624 520 L624 160 Q624 120 584 120 L320 120 L260 60 Q240 40 200 40 L40 40 Q0 40 0 80 Z" fill="#FCD34D"/>
    <path d="M0 160 L624 160 L624 520 Q624 560 584 560 L40 560 Q0 560 0 520 Z" fill="#FBBF24"/>
    <!-- Play/launch arrow -->
    <path d="M240 280 L420 380 L240 480 Z" fill="#4F46E5"/>
  </g>
</svg>'''
    return svg

def main():
    os.makedirs(ICON_DIR, exist_ok=True)
    
    # Create SVG
    svg_path = os.path.join(ICON_DIR, "icon.svg")
    with open(svg_path, 'w') as f:
        f.write(create_icon_svg())
    
    print(f"Created SVG icon at {svg_path}")
    print("\nTo convert to PNG icons, you can use an online converter or Inkscape:")
    print(f"  inkscape {svg_path} -w 1024 -h 1024 -o icon_1024.png")
    print("\nOr use the macOS built-in iconutil after creating PNGs.")

if __name__ == "__main__":
    main()
