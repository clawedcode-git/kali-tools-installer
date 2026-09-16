# Kali Tools Installer

A universal shell script to install all Kali Linux tools on any Linux distribution. Primary target: CachyOS (Arch-based). Supports Debian, Ubuntu, Fedora, Arch, Slackware, and more.

## Features

- **Cross-distribution support**: Automatically detects your distribution and uses the appropriate package manager
- **Curated tool presets**: Quick installations using presets like `top10`, `default`, `headless`, `web`, `wireless`, and `passwords`
- **Extensive Kali toolset**: Installs curated penetration testing and security auditing tools across 12 categories
- **100% Arch Linux / CachyOS coverage**: Complete official repo and AUR mappings for all 171 tools with native `pacman` and unprivileged `yay`/`paru` helper integration
- **BlackArch repository integration**: Optional bootstrapping of BlackArch repositories on Arch/CachyOS (`--enable-blackarch`) providing access to thousands of precompiled security packages
- **Build-from-source engine**: Automated fallback compilation for tools missing from native repos (supports Go, Python/pip, CMake, Make, and Git clones)
- **Automated dependency resolution**: Resolves and pre-installs required runtime dependencies (`deps` column) and automatically provisions build prerequisites (`go`, `python3-pip`, `cmake`, `make`, `gcc`, `git`) before compiling source fallbacks
- **Tool uninstallation & cleanup engine**: Cleanly remove installed tools, presets, or categories (`--uninstall` / `--remove`) via native package managers and purge `/usr/local/bin` and `/opt` source build files with safe `--dry-run` previews
- **Persistent configuration file**: Store defaults (distribution, presets, categories, tools, BlackArch enablement, log locations) in `${XDG_CONFIG_HOME:-~/.config}/kali-installer/config`, `/etc/kali-installer/config`, or a custom path with `--config <path>`
- **ASCII art banner & retro BBS menus**: Dynamic typography banner with real-time environment dashboard and instant single-key BBS menus for interactive exploration, presets, categories, and settings
- **Docker & CI automation**: Universal multi-distro `Dockerfile`, `docker-compose.yml`, local container test runner (`scripts/docker-test.sh`), and GitHub Actions CI matrix testing across 6 distributions on every push and PR
- **High-performance batch installation**: Bundles packages into single native package transactions with automatic individual-package fallback on failure
- **In-memory package resolution**: $O(1)$ tool-to-distro package mapping lookup without repeated disk/awk overhead
- **Interactive & non-interactive modes**: Run manually or automate in CI/CD
- **Modular design**: Easy to extend for new distributions
- **Package availability precheck & dry-run**: Query repositories before installing to see what's available and preview planned execution commands without root privileges

## Quick Start

```bash
# Clone and run
git clone https://github.com/clawedcode-git/kali-tools-installer.git
cd kali-tools-installer
sudo ./install.sh
```

## Installation

### Requirements

- Root/sudo access (for package installation; precheck, dry-run, and tool listing can run unprivileged)
- Bash 4.0+
- Internet connection
- Supported Linux distribution

### Supported Distributions

| Distribution | Package Manager | Status |
|--------------|-----------------|--------|
| **CachyOS** | pacman | ✅ Primary target |
| **Arch Linux** | pacman | ✅ Fully supported |
| **Manjaro** | pacman | ✅ Fully supported |
| **Debian** | apt | ✅ Supported |
| **Ubuntu** | apt | ✅ Supported |
| **Kali Linux** | apt | ✅ Native |
| **Fedora** | dnf | ✅ Supported |
| **RHEL/CentOS/Rocky/Alma** | dnf/yum | ✅ Supported |
| **openSUSE** | zypper | ✅ Supported |
| **Slackware** | slackpkg/sbopkg | ✅ Supported |
| **Gentoo** | emerge | ✅ Supported |
| **Alpine** | apk | ✅ Supported |
| **Void** | xbps | ✅ Supported |

## Usage

### Interactive Mode (Default)

Running without arguments launches the **BBS Retro Style Menu System** with an ASCII art banner and real-time environment dashboard:

```bash
sudo ./install.sh
```

```text
  _  __     _ _   _____           _       
 | |/ /__ _| (_) |_   _|__   ___ | |___   
 | ' // _` | | |   | |/ _ \ / _ \| / __|  
 | . \ (_| | | |   | | (_) | (_) | \__ \  
 |_|\_\__,_|_|_|   |_|\___/ \___/|_|___/  
        [ OFFENSIVE SECURITY TOOLSET ]    
┌─────────────────────────────────────────────────────────────┐
│ OS: CachyOS (arch)   │ PkgMgr: pacman  │ BlackArch: Enabled │
│ Tools: 171 Total     │ Presets: 6 Curated │ Deps: Auto         │
└─────────────────────────────────────────────────────────────┘

╔═════════════════════════════════════════════════════════════╗
║                    MAIN SELECTION MENU                    ║
╚═════════════════════════════════════════════════════════════╝

  [1]  ⚡ Quick Presets (top10, default, headless, web...)
  [2]  📦 Category Explorer (info, vuln, web, password...)
  [3]  🔍 Select Specific Tools (~171 Available)
  [4]  🚀 Install All 171 Kali Tools
  [5]  🔎 Repository Availability Precheck
  [6]  🗑️  Tool Uninstallation & Cleanup Engine
  [7]  📋 View Currently Installed Tools
  [8]  ⚙️  Toggle Options (Dry-Run, Deps, BlackArch)
  [Q]  🚪 Exit Installer
```

- **Instant Keypress Navigation**: Press single hotkeys (`1`-`8`, `Q`) to navigate menus instantly without needing to press Enter.
- **Dedicated Submenus**: Browse curated tool presets with tool counts, explore categories, select specific tools, or test repository availability.
- **Non-Interactive & Plain Modes**: The menu system automatically degrades to standard streams when redirected, in CI/CD, when passing `--yes`, or via `--no-tui` / `--plain`.

### Non-Interactive Mode (Automation)

```bash
# Install Top 10 Kali tools on Arch / CachyOS
sudo ./install.sh --distro arch --preset top10 --yes

# Install headless pentesting suite on Debian / Ubuntu server
sudo ./install.sh --distro debian --preset headless --yes

# Install all tools on Arch-based distro
sudo ./install.sh --distro arch --yes

# Install specific categories on Debian
sudo ./install.sh --distro debian --categories "web,vuln,forensics" --yes

# Install on Slackware
sudo ./install.sh --distro slackware --categories "password,wireless" --yes

# Install tools while skipping automatic dependency pre-installation
sudo ./install.sh --distro arch --tools nmap,wireshark --no-deps --yes

# Uninstall Top 10 Kali tools on Arch / CachyOS
sudo ./install.sh --distro arch --preset top10 --uninstall --yes

# Preview uninstallation without root privileges
./install.sh --distro debian --tools nmap,wireshark --remove --dry-run

# Dry run (show what would be installed, unprivileged)
./install.sh --distro fedora --preset top10 --dry-run
```

### Package Availability Precheck & Dry-Run

Before installing, check what packages are actually available in your distribution's repositories, or preview the complete execution pipeline without making changes (works without root):

```bash
# Check preset availability for a distro
./install.sh --distro arch --preset top10 --precheck

# Check all categories for a distro
./install.sh --distro arch --precheck

# Check specific categories
./install.sh --distro arch --categories "web,password" --precheck

# Combine precheck with dry-run to inspect repo availability AND preview install commands
./install.sh --distro arch --categories "web,vuln" --precheck --dry-run

# Dry run on a foreign distro
./install.sh --distro fedora --dry-run
```

The precheck queries your distribution's package repositories and shows:
- **Per-category / per-preset statistics**: Total tools, available count, percentage, missing count
- **Missing packages**: Lists tools not found in repositories
- **Buildable from source**: Identifies missing packages that can be compiled (Go, Python, CMake, make, etc.)
- **Runtime dependencies**: Identifies and lists runtime dependencies required across selected tools
- **Overall summary**: Total availability percentage across all categories

When combined with `--dry-run`, the installer evaluates availability, plans the batch native package transactions, falls back to source compilation where recipes exist, and outputs the exact command lines that would be executed.

### Command Line Options

| Option | Description |
|--------|-------------|
| `--distro <name>` | Force distribution (arch, debian, fedora, slackware, opensuse, gentoo, alpine, void) |
| `--preset <name>` | Install curated preset (top10, default, headless, web, wireless, passwords) |
| `--categories <list>` | Comma-separated categories to install |
| `--tools <list>` | Comma-separated specific tools to install |
| `--config <path>` | Load custom configuration file |
| `--yes`, `-y` | Skip confirmations |
| `--dry-run` | Preview planned native package commands and source builds without installing |
| `--precheck` | Check repository package availability and buildability (combines with `--dry-run`) |
| `--enable-blackarch` | Enable BlackArch repository on Arch/CachyOS |
| `--no-tui`, `--plain` | Disable ASCII banner styling and BBS interactive menus |
| `--no-update` | Skip package database update |
| `--no-deps` | Skip automatic dependency pre-installation |
| `--uninstall`, `--remove` | Uninstall targeted tools, presets, or categories |
| `--log-file <path>` | Custom log location (default: /var/log/kali-tools-install.log, fallback /tmp) |
| `--list-installed` | List installed Kali tools |
| `--help`, `-h` | Show help |

## Tool Presets

Curated bundles designed for common use cases:

| Preset | Description | Tool Count | Tools Included |
|--------|-------------|------------|----------------|
| `top10` | Essential Kali Top 10 pentesting tools | 10 | `aircrack-ng`, `burpsuite`, `hydra`, `john`, `hashcat`, `metasploit-framework`, `nikto`, `nmap`, `sqlmap`, `wireshark` |
| `default` | Core Kali default penetration testing suite | 35 | Essential tools across info gathering, web, exploitation, passwords, and sniffing |
| `headless` | CLI-only suite for cloud VPS, remote servers & containers | 32 | Terminal-based tools without X11/GUI dependencies |
| `web` | Web application security assessment bundle | 10 | `burpsuite`, `owasp-zap`, `nikto`, `dirb`, `gobuster`, `wfuzz`, `whatweb`, `wpscan`, `joomscan`, `cmsmap` |
| `wireless` | Wireless network auditing & attack suite | 10 | `aircrack-ng`, `wifite`, `kismet`, `reaver`, `bully`, `pixiewps`, `wash`, `fern-wifi-cracker`, `mdk3`, `mdk4` |
| `passwords` | Password cracking, brute-forcing & dictionary generation | 8 | `john`, `hashcat`, `hydra`, `medusa`, `ncrack`, `crunch`, `cewl`, `cupp` |

## Tool Categories

Kali tools are organized into categories. Install all or select specific ones:

| Category | Description | Example Tools |
|----------|-------------|---------------|
| `info` | Information gathering | nmap, masscan, recon-ng, dnsrecon |
| `vuln` | Vulnerability analysis | openvas, nikto, sqlmap, wpscan |
| `web` | Web application analysis | burpsuite, owasp-zap, dirb, gobuster |
| `password` | Password attacks | hashcat, john, hydra, medusa |
| `wireless` | Wireless attacks | aircrack-ng, wifite, kismet, reaver |
| `exploit` | Exploitation tools | metasploit-framework, exploitdb, searchsploit |
| `forensics` | Digital forensics | autopsy, sleuthkit, volatility, bulk-extractor |
| `reverse` | Reverse engineering | ghidra, radare2, gdb, ida-free |
| `hardware` | Hardware hacking | rtl-sdr, hackrf, ubertooth, yardstick |
| `reporting` | Reporting tools | faraday, dradis, magictree |
| `sniffing` | Sniffing & spoofing | wireshark, tcpdump, ettercap, bettercap |
| `maintaining` | Maintaining access | powershell-empire, Covenant, sliver |

## Configuration

### Master Tool List

Edit `config/kali-tools.list` to customize which tools are installed:

```ini
# Format: tool_name|category|description|debian_pkg|arch_pkg|fedora_pkg|slackware_pkg|opensuse_pkg|gentoo_pkg|alpine_pkg|void_pkg|deps
nmap|info|Network exploration and security auditing|nmap|nmap|nmap|nmap|nmap|net-analyzer/nmap|nmap|nmap|python3-pip,curl
metasploit-framework|exploit|Metasploit Framework|metasploit-framework|metasploit|metasploit-framework|metasploit-framework|metasploit-framework||||
burpsuite|web|Web proxy and scanner|burpsuite||burpsuite|burpsuite|burpsuite||||
```

### Persistent Configuration File

The installer supports persistent configuration files to save preferred defaults across executions without repeatedly typing command-line arguments.

#### Search Precedence (Highest to Lowest)
1. **Command-line flags**: `--distro`, `--preset`, `--tools`, `--yes`, etc.
2. **Explicit configuration flag**: `--config <path>`
3. **User-level configuration**: `${XDG_CONFIG_HOME:-~/.config}/kali-installer/config`
4. **System-wide configuration**: `/etc/kali-installer/config`
5. **Built-in defaults**

#### Configuration Format & Options
An example configuration file is provided in [`config/kali-installer.conf.example`](config/kali-installer.conf.example):

```ini
# Distribution override (arch, debian, fedora, slackware, opensuse, gentoo, alpine, void)
distro = arch

# Tool preset (top10, default, headless, web, wireless, passwords)
preset = top10

# Categories or tools
# categories = web, vuln
# tools = nmap, wireshark, aircrack-ng

# BlackArch repository bootstrapping (Arch/CachyOS only)
enable_blackarch = false

# Skip package database sync
no_update = false

# Automatic dependency pre-installation
install_deps = true

# Custom log file location
log_file = /var/log/kali-tools-install.log

# Non-interactive confirmations
yes = false

# Dry-run execution preview
dry_run = false
```

```bash
# Copy template to user configuration directory
mkdir -p ~/.config/kali-installer
cp config/kali-installer.conf.example ~/.config/kali-installer/config

# Run with custom configuration file
sudo ./install.sh --config /path/to/custom.conf
```

### Adding New Distributions

1. Add detection logic in `lib/distro.sh`
2. Add package manager commands in `lib/installer.sh`
3. Add package mappings in `config/kali-tools.list`
4. Test and submit PR

## Logging

All operations are logged to `/var/log/kali-tools-install.log` by default (automatically falls back to `/tmp/kali-tools-install-${UID}.log` when run without root privilege).

- **Clean & Grep-Friendly**: Raw ANSI color escape sequences are automatically stripped when writing to disk and when stdout is redirected to a non-TTY pipe, keeping log files clean and readable in any pager or text editor.
- **Interactive Colors**: Full ANSI color formatting is maintained during interactive terminal sessions.

```bash
# View live logs
tail -f /var/log/kali-tools-install.log

# View summary after install
grep -E "(SUCCESS|FAILED|SUMMARY)" /var/log/kali-tools-install.log
```

## Docker & Container Automation

Self-contained container environments are provided for local testing and deployment without impacting your host system.

### Universal Multi-Distro Dockerfile

The included [`Dockerfile`](Dockerfile) supports building for any supported Linux base image (`archlinux`, `ubuntu`, `debian`, `fedora`, `alpine`, `opensuse`):

```bash
# Build default Arch Linux image
docker build -t kali-installer .

# Build for Ubuntu 24.04
docker build --build-arg BASE_IMAGE=ubuntu:24.04 -t kali-installer:ubuntu .

# Build for Fedora 40
docker build --build-arg BASE_IMAGE=fedora:40 -t kali-installer:fedora .

# Run non-interactive installation preview inside container
docker run --rm -it kali-installer --preset top10 --dry-run
```

### Docker Compose Multi-Distro Testing

Use [`docker-compose.yml`](docker-compose.yml) to spin up isolated container environments for any distribution with the repository live-mounted:

```bash
# Run test suite in an Arch Linux container
docker compose run --rm arch

# Run test suite in an Ubuntu container
docker compose run --rm ubuntu

# Run test suite in a Debian container
docker compose run --rm debian

# Run test suite in an Alpine container
docker compose run --rm alpine
```

### Local Multi-Distro Test Runner (`scripts/docker-test.sh`)

A dedicated script [`scripts/docker-test.sh`](scripts/docker-test.sh) automates testing across any target distribution using Docker or Podman:

```bash
# Test on a specific distribution
./scripts/docker-test.sh arch
./scripts/docker-test.sh debian
./scripts/docker-test.sh fedora

# Test across all distributions sequentially
./scripts/docker-test.sh all

# Execute custom installer command inside an Arch container
./scripts/docker-test.sh arch ./install.sh --preset top10 --dry-run
```

### Continuous Integration (GitHub Actions)

Every push and pull request triggers [`.github/workflows/ci.yml`](.github/workflows/ci.yml), which executes:
1. **Script syntax validation** (`bash -n` and `shellcheck`).
2. **Containerized matrix testing** across 6 distributions:
   - Arch Linux (`archlinux:latest`)
   - Ubuntu 24.04 LTS (`ubuntu:24.04`)
   - Debian 12 Bookworm (`debian:bookworm`)
   - Fedora 40 (`fedora:40`)
   - Alpine Linux (`alpine:latest`)
   - openSUSE Tumbleweed (`opensuse/tumbleweed:latest`)
3. **Multi-distro Dockerfile build verification**.

## Troubleshooting

### Common Issues

**Package not found in official repos (Arch/AUR)**
On Arch Linux and CachyOS, tools not in official repositories are installed seamlessly via AUR helpers (`yay` or `paru`). When the installer runs under `sudo`, it automatically drops privileges to run AUR helpers as the invoking user (`sudo -u "${SUDO_USER}"`):
```bash
# Ensure base development packages and an AUR helper are present
sudo pacman -S --needed base-devel git
# Install yay or paru if not already installed
```

**BlackArch repository setup (Arch / CachyOS)**
You can optionally bootstrap the official BlackArch repository to access over 2,800 precompiled penetration testing tools:
```bash
sudo ./install.sh --distro arch --enable-blackarch
```
In interactive mode on Arch-based distros, the installer will automatically detect if `[blackarch]` is configured in `/etc/pacman.conf` and offer to configure it for you.

**Build-from-source fallback**
When a package is neither in native package manager repositories nor available via AUR, the installer checks for an upstream compilation recipe:
- **Go**: `go install <url>@latest`
- **Python**: `pip install --upgrade <url>`
- **CMake**: `cmake -B build && cmake --build build && cmake --install build`
- **Make**: `make && make install`
- **Git**: `git clone <url> /opt/<tool>`

**Automatic Dependency Resolution & Build Prerequisites**
The installer reads the `deps` column in `config/kali-tools.list` to identify runtime requirements (`libpcap`, `python3-pip`, `curl`, `git`, `ruby`, etc.) and automatically installs them via the native package manager before installing tools. When falling back to compiling from source, build prerequisites (`go`, `python3-pip`, `cmake`, `make`, `gcc`, `git`, `base-devel`) are verified and provisioned automatically beforehand. To skip dependency management, pass `--no-deps`.

**Package database out of sync**
```bash
# Force package database update
sudo ./install.sh
# Or skip if already up-to-date
sudo ./install.sh --no-update
```

**Permission denied**
```bash
# Ensure running as root for actual installations
sudo ./install.sh
# Read-only operations (--dry-run, --precheck, --list-installed, --help) do not require root
./install.sh --dry-run
```

**Network issues**
```bash
# Use local mirror by setting environment
export PACMAN_MIRROR="https://mirror.example.com/archlinux/\$repo/os/\$arch"
sudo -E ./install.sh
```

### Verification

After installation, verify tools are available:

```bash
# Quick verification
./tests/test_install.sh

# Check specific tool
which nmap && nmap --version

# List all installed Kali tools
./install.sh --list-installed
```

## Development

### Project Structure

```
kali-tools-installer/
├── .github/
│   └── workflows/
│       └── ci.yml          # GitHub Actions multi-distro CI workflow
├── Dockerfile              # Universal multi-distro container definition
├── docker-compose.yml      # Multi-distro container environment configuration
├── install.sh              # Main entry point
├── lib/
│   ├── distro.sh           # Distribution detection
│   ├── packages.sh         # Package name mappings
│   ├── installer.sh        # Installation orchestration
│   ├── menu.sh             # BBS retro style menu system
│   └── utils.sh            # Shared utilities (logging, banner, config)
├── config/
│   ├── kali-installer.conf.example # Example configuration file
│   └── kali-tools.list     # Master tool definitions
├── scripts/
│   └── docker-test.sh      # Local multi-distro test runner
├── tests/
│   └── test_install.sh     # Verification tests
└── AGENTS.md               # Agent instructions
```

### Running Tests

The test suite contains 46 automated tests verifying distribution detection, package caching, column isolation, argument validation, dry-run safety, BlackArch repository bootstrapping, tool presets, dependency resolution, tool uninstallation/cleanup, persistent configuration files, CI & Docker automation, ASCII banner & BBS menus, build recipes, and clean logging:

```bash
# Run the complete test suite
./tests/test_install.sh

# Test distribution detection with custom or mocked os-release
OS_RELEASE_FILE="/path/to/os-release" ./tests/test_install.sh

# Test specific distribution resolution
bash -c 'source lib/utils.sh; source lib/distro.sh; FORCE_DISTRO=arch detect_distro'
```

### Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/new-distro`)
3. Add distribution support following existing patterns
4. Update `config/kali-tools.list` with package mappings
5. Test on target distribution
6. Submit PR with distribution name in title

## License

MIT License - see LICENSE file for details.

## Acknowledgments

- [Kali Linux](https://www.kali.org/) for the comprehensive tool collection
- Package maintainers across all supported distributions
- Community contributors testing on various distros

## Support

- **Issues**: GitHub Issues for bugs and feature requests
- **Discussions**: GitHub Discussions for questions and help
- **Wiki**: Additional documentation and guides