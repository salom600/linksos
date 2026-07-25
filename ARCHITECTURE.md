# LinkSOS Linux Architecture

## System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      USER EXPERIENCE LAYER                       │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                    LinkSOS Desktop                          ││
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐ ││
│  │  │  Waybar  │ │   Rofi   │ │   Dunst  │ │   SDDM       │ ││
│  │  │(Taskbar) │ │(Launcher)│ │ (Notify) │ │  (Login)     │ ││
│  │  └──────────┘ ┌──────────┘ ┌──────────┘ ┌──────────────┘ ││
│  │                    ┌──────────────────┐                     ││
│  │                    │   Hyprland       │                     ││
│  │                    │  (Wayland WM)    │                     ││
│  │                    │  - Blur/Shadow   │                     ││
│  │                    │  - Animations    │                     ││
│  │                    │  - Rounded Corners│                    ││
│  │                    └──────────────────┘                     ││
│  └─────────────────────────────────────────────────────────────┘│
├─────────────────────────────────────────────────────────────────┤
│                    APPLICATION LAYER                              │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │  ┌────────────┐ ┌────────────┐ ┌────────────┐             ││
│  │  │ App Center │ │ Calamares  │ │  Dolphin   │             ││
│  │  │(Flatpak/   │ │(Installer) │ │(File Mgr)  │             ││
│  │  │ Native)    │ │            │ │            │             ││
│  │  └────────────┘ └────────────┘ └────────────┘             ││
│  │  ┌────────────┐ ┌────────────┐ ┌────────────┐             ││
│  │  │   Brave    │ │  Konsole   │ │   Kate     │             ││
│  │  │ (Browser)  │ │ (Terminal) │ │  (Editor)  │             ││
│  │  └────────────┘ └────────────┘ └────────────┘             ││
│  └─────────────────────────────────────────────────────────────┘│
├─────────────────────────────────────────────────────────────────┤
│                    GAMING LAYER                                   │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │  ┌────────────┐ ┌────────────┐ ┌────────────┐             ││
│  │  │   Wine     │ │   Proton   │ │   Lutris   │             ││
│  │  │(Windows    │ │(Steam      │ │(Game Mgr)  │             ││
│  │  │ compat)    │ │ compat)    │ │            │             ││
│  │  └────────────┘ └────────────┘ └────────────┘             ││
│  │  ┌────────────┐ ┌────────────┐ ┌────────────┐             ││
│  │  │ MangoHud   │ │ GameMode   │ │ Gamescope  │             ││
│  │  │(Overlay)   │ │(Optimizer) │ │(Rescaler)  │             ││
│  │  └────────────┘ └────────────┘ └────────────┘             ││
│  └─────────────────────────────────────────────────────────────┘│
├─────────────────────────────────────────────────────────────────┤
│                    DRIVER LAYER                                   │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │  ┌────────────┐ ┌────────────┐ ┌────────────┐             ││
│  │  │   NVIDIA   │ │    AMD     │ │   Intel    │             ││
│  │  │ (DKMS)     │ │ (Mesa)     │ │  (Mesa)    │             ││
│  │  │ + Vulkan   │ │ + Vulkan   │ │ + Vulkan   │             ││
│  │  │ + 32-bit   │ │ + 32-bit   │ │ + 32-bit   │             ││
│  │  └────────────┘ └────────────┘ └────────────┘             ││
│  │                    ┌──────────────┐                         ││
│  │                    │    Mesa      │                         ││
│  │                    │  (OpenGL/    │                         ││
│  │                    │   Vulkan)    │                         ││
│  │                    └──────────────┘                         ││
│  └─────────────────────────────────────────────────────────────┘│
├─────────────────────────────────────────────────────────────────┤
│                    PLATFORM LAYER                                 │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │  ┌────────────┐ ┌────────────┐ ┌────────────┐             ││
│  │  │ NetworkMgr │ │  PipeWire  │ │  BlueZ     │             ││
│  │  │(Network)   │ │  (Audio)   │ │ (Bluetooth)│             ││
│  │  └────────────┘ └────────────┘ └────────────┘             ││
│  │  ┌────────────┐ ┌────────────┐ ┌────────────┐             ││
│  │  │   Udisks   │ │   CUPS     │ │ FirewallD  │             ││
│  │  │ (Storage)  │ │ (Print)    │ │ (Security) │             ││
│  │  └────────────┘ └────────────┘ └────────────┘             ││
│  │                    ┌──────────────┐                         ││
│  │                    │   systemd    │                         ││
│  │                    │  (init/      │                         ││
│  │                    │  service     │                         ││
│  │                    │  manager)    │                         ││
│  │                    └──────────────┘                         ││
│  └─────────────────────────────────────────────────────────────┘│
├─────────────────────────────────────────────────────────────────┤
│                    BASE SYSTEM LAYER                              │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                    ┌──────────────┐                         ││
│  │                    │Arch Linux    │                         ││
│  │                    │  + pacman    │                         ││
│  │                    │  + systemd   │                         ││
│  │                    │  + glibc     │                         ││
│  │                    │  + multilib  │                         ││
│  │                    └──────────────┘                         ││
│  └─────────────────────────────────────────────────────────────┘│
├─────────────────────────────────────────────────────────────────┤
│                    KERNEL LAYER                                   │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                    ┌──────────────┐                         ││
│  │                    │ linux-zen    │                         ││
│  │                    │ (optimized   │                         ││
│  │                    │  for low     │                         ││
│  │                    │  latency &   │                         ││
│  │                    │  gaming)     │                         ││
│  │                    └──────────────┘                         ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

## RAM Budget Analysis (Idle State)

| Component | Estimated RAM | Notes |
|-----------|--------------|-------|
| linux-zen kernel | 30-50 MB | Optimized for low latency |
| systemd + dbus | 15-20 MB | Essential services only |
| Hyprland compositor | 20-30 MB | Wayland compositor (much lighter than X11 compositors) |
| Waybar | 5-10 MB | Single process taskbar |
| PipeWire + WirePlumber | 8-12 MB | Modern audio stack |
| NetworkManager | 5-8 MB | Network management |
| Dunst | 2-3 MB | Notification daemon |
| Polkit agent | 2-3 MB | Permission management |
| SDDM (idle) | 0 MB | Only runs during login |
| **TOTAL ESTIMATED** | **87-136 MB** | **Below 200 MB target** |

## Boot Process Flow

```
BIOS/UEFI → GRUB → linux-zen kernel → systemd init →
  ├─ NetworkManager (network)
  ├─ PipeWire (audio)
  ├─ BlueZ (bluetooth)
  ├─ dbus-broker (message bus)
  └─ SDDM (login manager) →
      └─ Hyprland (desktop compositor) →
          ├─ Waybar (taskbar)
          ├─ Dunst (notifications)
          ├─ Rofi (launcher)
          └─ User session
```

## Theme Architecture (Windows 11 / macOS Hybrid)

```
Visual Design Philosophy:
┌─────────────────────────────────────────┐
│  PRIMARY: Windows 11                    │
│  - Bottom taskbar (Waybar)              │
│  - Start menu equivalent (Rofi drun)    │
│  - System tray integration              │
│  - Window snapping (Hyprland)           │
│  - Rounded corners (12px)               │
│                                         │
│  SECONDARY: macOS                       │
│  - Smooth animations (Hyprland bezier)  │
│  - Blur effects (Hyprland blur)         │
│  - Drop shadows (Hyprland shadows)      │
│  - Clean, minimal aesthetic             │
│                                         │
│  COLOR PALETTE: GitHub Dark             │
│  - Background: #0d1117                  │
│  - Surface: #161b22                     │
│  - Border: #30363d                      │
│  - Text: #c9d1d9                        │
│  - Accent: #58a6ff                      │
│  - Error: #f85149                       │
│  - Warning: #d29922                     │
└─────────────────────────────────────────┘
```

## Gaming Architecture

```
Game Launch Flow:
┌──────────────────────────────────────────────┐
│  Native Linux Game                            │
│  └─ Steam/Linux → Direct execution            │
│                                               │
│  Windows Game via Proton                      │
│  └─ Steam → Proton → Wine → DXVK → Game      │
│                                               │
│  Windows Game via Lutris                      │
│  └─ Lutris → Wine/Proton → DXVK → Game       │
│                                               │
│  Performance Overlay                          │
│  └─ MangoHud (FPS, CPU, GPU, RAM overlay)     │
│                                               │
│  Performance Optimization                     │
│  └─ GameMode (CPU governor, process priority) │
│  └─ Gamescope (resolution scaling, HDR)       │
│                                               │
│  Graphics Stack                               │
│  ┌────────────────────────────────────────┐   │
│  │  NVIDIA: nvidia-dkms + vulkan          │   │
│  │  AMD:    mesa + vulkan-radeon          │   │
│  │  Intel:  mesa + vulkan-intel           │   │
│  │  All:    DXVK (DX→VK translation)      │   │
│  └────────────────────────────────────────┘   │
└──────────────────────────────────────────────┘
```

## CI/CD Build Pipeline

```
GitHub Actions Build Flow:
┌──────────────────────────────────────────────┐
│  Push to main / workflow_dispatch             │
│          │                                    │
│          ▼                                    │
│  ┌─────────────────────────┐                  │
│  │  Step 1: Checkout       │                  │
│  │  + Init Arch container  │                  │
│  │  + Install archiso      │                  │
│  │  + Setup mirrorlist     │                  │
│  └─────────────────────────┘                  │
│          │                                    │
│          ▼                                    │
│  ┌─────────────────────────┐                  │
│  │  Step 2: Keyring setup  │                  │
│  │  + archlinuxcn-keyring  │                  │
│  │  + pacman-key init      │                  │
│  └─────────────────────────┘                  │
│          │                                    │
│          ▼                                    │
│  ┌─────────────────────────┐                  │
│  │  Step 3: Profile verify │                  │
│  │  + Check profiledef.sh  │                  │
│  │  + Check packages list  │                  │
│  └─────────────────────────┘                  │
│          │                                    │
│          ▼                                    │
│  ┌─────────────────────────┐                  │
│  │  Step 4: mkarchiso      │                  │
│  │  (Core build - 2-4 hrs) │                  │
│  │  - Package installation │                  │
│  │  - customize_airootfs   │                  │
│  │  - squashfs compression │                  │
│  │  - ISO generation       │                  │
│  └─────────────────────────┘                  │
│          │                                    │
│          ▼                                    │
│  ┌─────────────────────────┐                  │
│  │  Step 5: Verify + hash  │                  │
│  │  + Check ISO exists     │                  │
│  │  + SHA256 checksum      │                  │
│  │  + Build info           │                  │
│  └─────────────────────────┘                  │
│          │                                    │
│          ▼                                    │
│  ┌─────────────────────────┐                  │
│  │  Step 6: Upload         │                  │
│  │  + Artifact upload      │                  │
│  │  + GitHub Release       │                  │
│  └─────────────────────────┘                  │
└──────────────────────────────────────────────┘
```

## Package Classification

| Category | Count | Key Packages |
|----------|-------|-------------|
| Base System | ~15 | base, linux-zen, systemd, dbus-broker |
| Desktop | ~8 | hyprland, waybar, rofi-wayland, dunst, sddm |
| Utilities | ~15 | dolphin, konsole, kate, ark, flatpak |
| Gaming | ~12 | wine, lutris, steam, mangohud, gamemode |
| Drivers | ~12 | mesa, nvidia-dkms, vulkan-radeon/intel |
| Networking | ~5 | networkmanager, iwd, blueman |
| Audio | ~8 | pipewire, wireplumber, pavucontrol |
| Theming | ~8 | tela-icon-theme, nwg-look, kvantum |
| **Total** | **~85** | |
