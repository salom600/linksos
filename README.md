# LinkSOS Linux

> **Modern. Lightweight. Gaming-Ready.**

A custom Arch Linux-based distribution designed for ex-Windows users and gamers, combining high performance with a modern Windows 11/macOS hybrid desktop aesthetic.

## Key Features

| Feature | Specification |
|---------|--------------|
| **Idle RAM** | ~120-150 MB |
| **Desktop** | Hyprland (Wayland) + Waybar |
| **Design** | Windows 11 / macOS hybrid (dark mode, blur, rounded corners) |
| **Installer** | Calamares (one-click graphical installer) |
| **Gaming** | Wine + Proton + Lutris + Steam pre-configured |
| **Browser** | Brave (privacy-focused) |
| **Kernel** | linux-zen (optimized for low latency) |
| **Audio** | PipeWire (modern audio stack) |

## Architecture

```
┌─────────────────────────────────────────┐
│  LinkSOS Desktop (Hyprland + Waybar)    │
├─────────────────────────────────────────┤
│  Gaming Layer (Wine/Proton/Lutris)      │
│  App Center (Flatpak/Native)            │
│  Calamares (One-Click Install)          │
├─────────────────────────────────────────┤
│  Drivers (NVIDIA/AMD/Intel + Vulkan)    │
│  Platform (NM/PipeWire/BlueZ/systemd)   │
├─────────────────────────────────────────┤
│  Arch Linux Base (pacman + multilib)    │
├─────────────────────────────────────────┤
│  linux-zen Kernel (gaming-optimized)    │
└─────────────────────────────────────────┘
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full system architecture diagram.

## Quick Start

### Build Locally (Arch Linux)

```bash
# Clone the repository
git clone https://github.com/salom600/linksos.git
cd linksos

# Build the ISO
chmod +x scripts/build-iso.sh
sudo ./scripts/build-iso.sh
```

### Build via Docker (Any OS)

```bash
# Clone and build inside Docker
git clone https://github.com/salom600/linksos.git
cd linksos

chmod +x scripts/docker-build.sh
./scripts/docker-build.sh
```

### Build via GitHub Actions (Automatic)

Push to the `main` branch or trigger manually via GitHub Actions. The ISO will be built and published to GitHub Releases automatically.

## Installation

1. **Download** the ISO from [GitHub Releases](https://github.com/salom600/linksos/releases)
2. **Flash** to USB using [Rufus](https://rufus.ie) (Windows) or `dd` (Linux)
3. **Boot** from USB
4. **Click** "Install LinkSOS" on the desktop
5. **Follow** the Calamares installer wizard

## Project Structure

```
linksos/
├── .github/workflows/build.yml   # CI/CD pipeline
├── archiso/
│   ├── profiledef.sh             # ISO profile definition
│   ├── packages.x86_64           # Package list
│   ├── pacman.conf               # Pacman configuration
│   ├── customize_airootfs.sh     # Post-install customization
│   └── airootfs/etc/             # System configuration overlay
│       ├── hypr/hyprland.conf    # Hyprland desktop config
│       ├── waybar/               # Waybar taskbar config
│       ├── calamares/            # Calamares installer config
│       ├── sddm.conf.d/          # SDDM login manager config
│       ├── skel/                 # Default user home files
│       └── systemd/system/       # Custom systemd services
├── scripts/
│   ├── build-iso.sh              # Local build script
│   └── docker-build.sh           # Docker build script
├── ARCHITECTURE.md               # System architecture document
└── README.md                     # This file
```

## Desktop Keybindings

| Key | Action |
|-----|--------|
| `Super + Enter` | Open terminal |
| `Super + Space` | Open launcher (Rofi) |
| `Super + E` | Open file manager |
| `Super + B` | Open browser |
| `Super + G` | Open Lutris/Steam |
| `Super + F` | Toggle fullscreen |
| `Super + V` | Toggle floating |
| `Super + Q` | Close window |
| `Super + 1-10` | Switch workspace |
| `Super + Shift + 1-10` | Move window to workspace |
| `Super + Print` | Take screenshot |
| `Super + L` | Lock screen |

## Performance Targets

| Metric | Target | Achieved |
|--------|--------|----------|
| Idle RAM | < 200 MB | ~120-150 MB |
| Boot time | < 30s | ~15-25s |
| ISO size | < 3 GB | ~2-2.5 GB |
| Build time | < 6 hours | ~2-4 hours |

## License

MIT License - See [LICENSE](LICENSE) for details.
