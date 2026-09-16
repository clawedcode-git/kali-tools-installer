# Kali Tools Installer

A universal shell script to install all Kali Linux tools on any Linux distribution. Primary target: CachyOS (Arch-based). Supports Debian, Ubuntu, Fedora, Arch, Slackware, and more.

## Features

- **Cross-distribution support**: Automatically detects your distribution and uses the appropriate package manager
- **Extensive Kali toolset**: Installs curated penetration testing and security auditing tools across 12 categories
- **Interactive & non-interactive modes**: Run manually or automate in CI/CD
- **Modular design**: Easy to extend for new distributions
- **Package availability precheck**: Query repositories before installing to see what's available

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
| **Gentoo** | emerge | 🟡 Planned |
| **Alpine** | apk | 🟡 Planned |

## Usage

### Interactive Mode (Default)

```bash
sudo ./install.sh
```

Prompts for:
- Distribution selection (auto-detected with confirmation)
- Installation scope: all tools, categories, or custom selection
- Confirmation before proceeding

### Non-Interactive Mode (Automation)

```bash
# Install all tools on Arch-based distro
sudo ./install.sh --distro arch --yes

# Install specific categories on Debian
sudo ./install.sh --distro debian --categories "web,vuln,forensics" --yes

# Install on Slackware
sudo ./install.sh --distro slackware --categories "password,wireless" --yes

# Dry run (show what would be installed, unprivileged)
./install.sh --distro fedora --dry-run
```

### Package Availability Precheck

Before installing, check what packages are actually available in your distribution's repositories (works without root):

```bash
# Check all categories for a distro
./install.sh --distro arch --precheck

# Check specific categories
./install.sh --distro arch --categories "web,password" --precheck

# Check for a different distro (e.g., openSUSE)
./install.sh --distro opensuse --precheck

# Combined with categories to inspect availability
./install.sh --distro fedora --categories "web,vuln" --precheck
```

The precheck queries your distribution's package repositories and shows:
- **Per-category statistics**: Total tools, available count, percentage, missing count
- **Missing packages**: Lists tools not found in repositories
- **Buildable from source**: Identifies missing packages that can be compiled (Go, Python, CMake, make, etc.)
- **Overall summary**: Total availability percentage across all categories

### Command Line Options

| Option | Description |
|--------|-------------|
| `--distro <name>` | Force distribution (arch, debian, fedora, slackware, opensuse, gentoo, alpine, void) |
| `--categories <list>` | Comma-separated categories to install |
| `--tools <list>` | Comma-separated specific tools to install |
| `--yes`, `-y` | Skip confirmations |
| `--dry-run` | Show packages without installing |
| `--no-update` | Skip package database update |
| `--log-file <path>` | Custom log location (default: /var/log/kali-tools-install.log, fallback /tmp) |
| `--list-installed` | List installed Kali tools |
| `--precheck` | Check package availability in repos (no install) |
| `--help`, `-h` | Show help |

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

### Adding New Distributions

1. Add detection logic in `lib/distro.sh`
2. Add package manager commands in `lib/installer.sh`
3. Add package mappings in `config/kali-tools.list`
4. Test and submit PR

## Logging

All operations are logged to `/var/log/kali-tools-install.log` by default (automatically falls back to `/tmp/kali-tools-install-${UID}.log` when run without root privilege).

```bash
# View live logs
tail -f /var/log/kali-tools-install.log

# View summary after install
grep -E "(SUCCESS|FAILED|SUMMARY)" /var/log/kali-tools-install.log
```

## Troubleshooting

### Common Issues

**Package not found errors**
```bash
# Update package databases first
sudo ./install.sh --no-update  # Skip if already updated
```

**Missing dependencies (Arch/AUR)**
```bash
# Install AUR helper first
sudo pacman -S --needed base-devel git
# Then run installer (uses yay/paru if available)
```

**Permission denied**
```bash
# Ensure running as root
sudo ./install.sh
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
├── install.sh              # Main entry point
├── lib/
│   ├── distro.sh           # Distribution detection
│   ├── packages.sh         # Package name mappings
│   ├── installer.sh        # Installation orchestration
│   └── utils.sh            # Shared utilities (logging, colors, etc.)
├── config/
│   └── kali-tools.list     # Master tool definitions
├── tests/
│   └── test_install.sh     # Verification tests
└── AGENTS.md               # Agent instructions
```

### Running Tests

```bash
# Run verification tests
./tests/test_install.sh

# Test specific distribution logic
bash -x lib/distro.sh
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