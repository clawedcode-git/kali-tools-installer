# Kali Tools Installer - Agent Instructions

## Project Overview
Shell script to install all Kali Linux tools on any distribution (primary target: CachyOS). Supports Debian, Arch, Fedora, Slackware, and other distros via package manager abstraction.

## Project Structure
```
kali-tools-installer/
├── install.sh              # Main entry point
├── lib/
│   ├── distro.sh           # Distribution detection
│   ├── packages.sh         # Package mappings per distro
│   ├── installer.sh        # Installation logic
│   └── utils.sh            # Shared utilities
├── config/
│   └── kali-tools.list     # Master list of Kali tools
└── tests/
    └── test_install.sh     # Basic verification tests
```

## Key Commands
```bash
# Run installer (interactive)
./install.sh

# Run installer non-interactive (for CI)
./install.sh --distro arch --yes

# Test on current distro
./tests/test_install.sh
```

## Distribution Support Matrix
| Distro | Package Manager | Status |
|--------|----------------|--------|
| CachyOS/Arch | pacman | Primary |
| Debian/Ubuntu | apt | Supported |
| Fedora | dnf | Supported |
| Slackware | slackpkg/sbopkg | Planned |

## Conventions
- **Distro detection**: `/etc/os-release` parsing in `lib/distro.sh`
- **Package mappings**: `config/kali-tools.list` maps tool → per-distro package names
- **Install logic**: Uses package manager native commands, falls back to building from source
- **Error handling**: Continue on individual package failures, report summary at end

## Development Notes
- No external dependencies beyond standard shell utilities
- Target: POSIX-compliant bash (tested on bash 4+)
- Run as root (sudo) for package installation
- Log output to `/var/log/kali-tools-install.log`