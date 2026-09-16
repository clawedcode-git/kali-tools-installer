#!/usr/bin/env python3
"""Generate assets/screenshot.svg showcasing the BBS retro style menu and Concept A banner."""
import html

width = 820
height = 840
font_family = "ui-monospace, SFMono-Regular, 'SF Mono', Menlo, Consolas, 'Liberation Mono', monospace"
font_size = 14
line_height = 23
start_y = 85

svg = []
svg.append(f"""<svg width="{width}" height="{height}" viewBox="0 0 {width} {height}" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="shadow" x="-20" y="-20" width="{width+40}" height="{height+40}" filterUnits="userSpaceOnUse">
      <feDropShadow dx="0" dy="14" stdDeviation="18" flood-color="#000000" flood-opacity="0.55"/>
    </filter>
    <linearGradient id="titlebar" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#21262d"/>
      <stop offset="100%" stop-color="#161b22"/>
    </linearGradient>
  </defs>

  <!-- Terminal Window Background -->
  <rect x="25" y="20" width="{width-50}" height="{height-40}" rx="12" fill="#0d1117" stroke="#30363d" stroke-width="1.5" filter="url(#shadow)"/>

  <!-- Title Bar -->
  <rect x="25" y="20" width="{width-50}" height="42" rx="12" fill="url(#titlebar)"/>
  <rect x="25" y="50" width="{width-50}" height="12" fill="#161b22"/>
  <line x1="25" y1="62" x2="{width-25}" y2="62" stroke="#30363d" stroke-width="1"/>

  <!-- Window Controls -->
  <circle cx="52" cy="41" r="6.5" fill="#ff5f56" stroke="#e0443e" stroke-width="0.5"/>
  <circle cx="74" cy="41" r="6.5" fill="#ffbd2e" stroke="#dea123" stroke-width="0.5"/>
  <circle cx="96" cy="41" r="6.5" fill="#27c93f" stroke="#1aab29" stroke-width="0.5"/>

  <!-- Title Text -->
  <text x="{width/2}" y="46" font-family="{font_family}" font-size="12.5" fill="#8b949e" text-anchor="middle" font-weight="500">kali-tools-installer — bash — 80x32</text>

  <!-- Terminal Content -->
  <g font-family="{font_family}" font-size="{font_size}" xml:space="preserve">
""")

def add_line(y, content):
    svg.append(f'    <text x="50" y="{y}">{content}</text>')

y = start_y
# Prompt
add_line(y, '<tspan fill="#38bdf8" font-weight="bold">#</tspan><tspan fill="#f0f6fc"> ./install.sh</tspan>')
y += int(line_height * 1.3)

# ASCII Banner
banner_lines = [
    "             _  __     _ _   _____           _       ",
    "            | |/ /__ _| (_) |_   _|__   ___ | |___   ",
    "            | ' // _` | | |   | |/ _ \\ / _ \\| / __|  ",
    "            | . \\ (_| | | |   | | (_) | (_) | \\__ \\  ",
    "            |_|\\_\\__,_|_|_|   |_|\\___/ \\___/|_|___/  "
]
for bl in banner_lines:
    add_line(y, f'<tspan fill="#38bdf8">{html.escape(bl)}</tspan>')
    y += line_height

add_line(y, '<tspan fill="#facc15">                   [ OFFENSIVE SECURITY TOOLSET ]    </tspan>')
y += line_height

# Dashboard Box
add_line(y, '<tspan fill="#3b82f6">┌───────────────────────────────────────────────────────────────┐</tspan>')
y += line_height

add_line(y, '<tspan fill="#3b82f6">│</tspan> <tspan fill="#22c55e" font-weight="bold">OS:</tspan> <tspan fill="#f1f5f9">cachyos (arch) </tspan><tspan fill="#3b82f6">│</tspan> <tspan fill="#22c55e" font-weight="bold">PkgMgr:</tspan> <tspan fill="#f1f5f9">pacman     </tspan><tspan fill="#3b82f6">│</tspan> <tspan fill="#22c55e" font-weight="bold">BlackArch:</tspan> <tspan fill="#22c55e">Enabled  </tspan><tspan fill="#3b82f6">│</tspan>')
y += line_height

add_line(y, '<tspan fill="#3b82f6">│</tspan> <tspan fill="#22c55e" font-weight="bold">Tools:</tspan> <tspan fill="#f1f5f9">171 Total   </tspan><tspan fill="#3b82f6">│</tspan> <tspan fill="#22c55e" font-weight="bold">Presets:</tspan> <tspan fill="#f1f5f9">6 Curated </tspan><tspan fill="#3b82f6">│</tspan> <tspan fill="#22c55e" font-weight="bold">Deps:</tspan> <tspan fill="#22c55e">Auto          </tspan><tspan fill="#3b82f6">│</tspan>')
y += line_height

add_line(y, '<tspan fill="#3b82f6">└───────────────────────────────────────────────────────────────┘</tspan>')
y += int(line_height * 1.3)

# Main Selection Header
add_line(y, '<tspan fill="#3b82f6">╔═══════════════════════════════════════════════════════════════╗</tspan>')
y += line_height
add_line(y, '<tspan fill="#3b82f6">║</tspan><tspan fill="#facc15" font-weight="bold">                      MAIN SELECTION MENU                      </tspan><tspan fill="#3b82f6">║</tspan>')
y += line_height
add_line(y, '<tspan fill="#3b82f6">╚═══════════════════════════════════════════════════════════════╝</tspan>')
y += int(line_height * 1.2)

# Menu items
items = [
    ("[1]", " ⚡ Quick Presets (top10, default, headless, web...)"),
    ("[2]", " 📦 Category Explorer (info, vuln, web, password...)"),
    ("[3]", " 🔍 Select Specific Tools (~171 Available)"),
    ("[4]", " 🚀 Install All 171 Kali Tools"),
    ("[5]", " 🔎 Repository Availability Precheck"),
    ("[6]", " 🗑️  Tool Uninstallation & Cleanup Engine"),
    ("[7]", " 📋 View Currently Installed Tools"),
    ("[8]", " ⚙️  Toggle Options (Dry-Run: false, Deps: true)"),
]

for hotkey, desc in items:
    add_line(y, f'  <tspan fill="#22c55e" font-weight="bold">{hotkey}</tspan><tspan fill="#f1f5f9">{html.escape(desc)}</tspan>')
    y += line_height

add_line(y, '  <tspan fill="#f87171" font-weight="bold">[Q]</tspan><tspan fill="#f1f5f9"> 🚪 Exit Installer</tspan>')
y += int(line_height * 1.2)

add_line(y, '<tspan fill="#3b82f6">─────────────────────────────────────────────────────────────────</tspan>')
y += int(line_height * 1.2)

add_line(y, '  <tspan fill="#f1f5f9">Select an option [1-8, Q]: </tspan><tspan fill="#38bdf8">█</tspan>')

svg.append("""  </g>
</svg>""")

with open("assets/screenshot.svg", "w", encoding="utf-8") as f:
    f.write("\n".join(svg))

print("Successfully generated assets/screenshot.svg")
