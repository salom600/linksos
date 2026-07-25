#!/usr/bin/env bash
# ==============================================================================
# LinkSOS - customize_airootfs.sh
# Post-install customization script for the live system chroot
# Runs INSIDE the airootfs chroot during archiso build
#
# IMPORTANT: This runs inside a chroot WITHOUT systemd running.
#   - systemctl enable/disable only create symlinks (no start/stop)
#   - Use `|| true` for commands that may legitimately fail
#   - Do NOT use strict `set -e` — CI builds must tolerate minor issues
# ==============================================================================

echo "==> [LinkSOS] Starting airootfs customization..."

# ==============================================================================
# 1. SYSTEM SERVICES
# ==============================================================================

echo "==> [LinkSOS] Enabling system services..."

# Essential services — these packages are guaranteed installed by packages.x86_64
systemctl enable NetworkManager.service || true
systemctl enable sddm.service || true
systemctl enable bluetooth.service || true
systemctl enable cups.service || true
systemctl enable power-profiles-daemon.service || true
systemctl enable systemd-resolved.service || true
systemctl enable systemd-timesyncd.service || true
systemctl enable reflector.service || true
systemctl enable avahi-daemon.service || true

# Disable unnecessary services for minimal RAM
systemctl disable lvm2-monitor.service 2>/dev/null || true

# ==============================================================================
# 2. USER SETUP
# ==============================================================================

echo "==> [LinkSOS] Setting up users..."

# Create live user
useradd -m -G wheel,audio,video,optical,storage,games,input,lp -s /bin/bash linksos 2>/dev/null || true

# Set passwords (format: user:password)
echo "linksos:linksos" | chpasswd || true
echo "root:linksos" | chpasswd || true

# Allow wheel group to sudo without password (for live session only)
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/99-wheel-nopasswd
chmod 0440 /etc/sudoers.d/99-wheel-nopasswd

# ==============================================================================
# 3. KERNEL OPTIMIZATION
# ==============================================================================

echo "==> [LinkSOS] Optimizing kernel parameters..."

cat > /etc/sysctl.d/99-linksos.conf << 'EOF'
# Minimal RAM usage
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_ratio=15
vm.dirty_background_ratio=5

# Gaming optimizations
kernel.sched_autogroup_enabled=1

# Network
net.core.somaxconn=1024
net.ipv4.tcp_fastopen=3

# Security
kernel.kptr_restrict=2
kernel.dmesg_restrict=1
EOF

# ==============================================================================
# 4. SDDM CONFIGURATION
# ==============================================================================

echo "==> [LinkSOS] Configuring SDDM..."

mkdir -p /etc/sddm.conf.d

cat > /etc/sddm.conf.d/linksos.conf << 'EOF'
[Autologin]
User=linksos
Session=hyprland

[Theme]
Current=linksos
CursorTheme=Adwaita
Font=Noto Sans

[General]
Numlock=on
EOF

# ==============================================================================
# 5. REFLECTOR CONFIGURATION
# ==============================================================================

echo "==> [LinkSOS] Configuring reflector..."

mkdir -p /etc/xdg/reflector

cat > /etc/xdg/reflector/reflector.conf << 'EOF'
--save /etc/pacman.d/mirrorlist
--protocol https
--latest 20
--sort rate
EOF

# ==============================================================================
# 6. CALAMARES CONFIGURATION
# ==============================================================================

echo "==> [LinkSOS] Configuring Calamares..."

mkdir -p /etc/calamares/modules
mkdir -p /etc/calamares/branding/linksos

# Main settings
cat > /etc/calamares/settings.conf << 'EOF'
---
branding: linksos
sequence:
  - show:
    - welcome
    - locale
    - keyboard
    - partition
    - users
    - summary
  - exec:
    - partition
    - mount
    - unpackfs
    - machineid
    - fstab
    - locale
    - keyboard
    - users
    - networkcfg
    - hwclock
    - services
    - grubcfg
    - bootloader
    - cleanup
  - show:
    - finished
prompt-install: false
dont-chroot: false
EOF

# Partition module
cat > /etc/calamares/modules/partition.conf << 'EOF'
---
defaultFileSystemType: "ext4"
availableFileSystemTypes: ["ext4", "btrfs", "xfs"]
partitionLayout:
  - name: "EFI"
    type: "efi"
    size: 512MiB
    mountPoint: "/boot"
  - name: "Root"
    type: "linux"
    size: 100%
    mountPoint: "/"
EOF

# Unpackfs module
cat > /etc/calamares/modules/unpackfs.conf << 'EOF'
---
unpack:
  - source: "/run/archiso/bootmnt/arch/x86_64/airootfs.sfs"
    sourcefs: "squashfs"
    destination: ""
EOF

# Users module
cat > /etc/calamares/modules/users.conf << 'EOF'
---
defaultGroups:
  - wheel
  - audio
  - video
  - optical
  - storage
  - games
  - input
  - lp
  - scanner
  - network
doAutologin: false
doReusePassword: true
passwordRequirements:
  minLength: 0
userShell: /bin/bash
setHostname: EtcFile
EOF

# Services module
cat > /etc/calamares/modules/services.conf << 'EOF'
---
services:
  enable:
    - NetworkManager
    - sddm
    - bluetooth
    - cups
    - power-profiles-daemon
    - systemd-resolved
    - systemd-timesyncd
    - reflector
    - avahi-daemon
  disable:
    - lvm2-monitor
targets:
  enable:
    - multi-user
EOF

# Bootloader module
cat > /etc/calamares/modules/bootloader.conf << 'EOF'
---
efiBootLoader: "grub"
kernel: "/boot/vmlinuz-linux-zen"
img: "/boot/initramfs-linux-zen.img"
fallback: "/boot/initramfs-linux-zen-fallback.img"
kernelParam: ["quiet", "splash", "loglevel=3", "mitigations=off", "nowatchdog", "nvidia-drm.modeset=1"]
grubInstall: "grub-install"
grubMkconfig: "grub-mkconfig"
grubCfg: "/boot/grub/grub.cfg"
EOF

# Machineid module
cat > /etc/calamares/modules/machineid.conf << 'EOF'
---
systemd: true
dbus: true
symlink: true
EOF

# Mount module
cat > /etc/calamares/modules/mount.conf << 'EOF'
---
extraMounts:
  - device: proc
    fs: proc
    mountPoint: /proc
  - device: sys
    fs: sysfs
    mountPoint: /sys
  - device: /dev
    fs: none
    mountPoint: /dev
    options: [bind]
  - device: tmpfs
    fs: tmpfs
    mountPoint: /run
  - device: /run/archiso/bootmnt
    fs: none
    mountPoint: /mnt/boot
    options: [bind]
EOF

# Fstab module
cat > /etc/calamares/modules/fstab.conf << 'EOF'
---
mountOptions:
  default: defaults,noatime
  btrfs: defaults,noatime,compress=zstd
ssdExtraMountOptions:
  ext4: discard
  btrfs: discard,compress=zstd
EOF

# Locale module
cat > /etc/calamares/modules/locale.conf << 'EOF'
---
region: "America"
zone: "New_York"
localeGenPath: "/etc/locale.gen"
EOF

# Keyboard module
cat > /etc/calamares/modules/keyboard.conf << 'EOF'
---
keyboardModels: []
keyboardLayouts:
  - us
EOF

# Networkcfg module
cat > /etc/calamares/modules/networkcfg.conf << 'EOF'
---
systemdNetworkd: false
EOF

# Hwclock module
cat > /etc/calamares/modules/hwclock.conf << 'EOF'
---
localtime: true
EOF

# Grubcfg module
cat > /etc/calamares/modules/grubcfg.conf << 'EOF'
---
overwrite: false
keepDistributor: true
EOF

# Welcome module
cat > /etc/calamares/modules/welcome.conf << 'EOF'
---
showSupportUrl: true
showKnownIssuesUrl: true
requiredStorage: 20
requiredRam: 2.0
internetCheckUrl: "https://archlinux.org"
EOF

# Finished module
cat > /etc/calamares/modules/finished.conf << 'EOF'
---
restartNowMode: user-unchecked
restartNowCommand: "systemctl -i reboot"
EOF

# Summary module
cat > /etc/calamares/modules/summary.conf << 'EOF'
---
show: true
EOF

# ==============================================================================
# 7. CALAMARES BRANDING
# ==============================================================================

echo "==> [LinkSOS] Creating Calamares branding..."

cat > /etc/calamares/branding/linksos/branding.desc << 'EOF'
---
componentName: linksos
strings:
  productName: LinkSOS Linux
  shortProductName: LinkSOS
  version: 2026.07
  shortVersion: "2026.07"
  versionedName: LinkSOS Linux 2026.07
  shortVersionedName: LinkSOS 2026.07
  bootloaderEntryName: LinkSOS
  productUrl: https://github.com/salom600/linksos
  supportUrl: https://github.com/salom600/linksos/issues
images:
  productLogo: "logo.png"
  productIcon: "icon.png"
slideshow: "show.qml"
style:
  sidebarBackground: "#0d1117"
  sidebarText: "#c9d1d9"
  sidebarTextSelect: "#58a6ff"
  sidebarTextHighlight: "#1f6feb"
EOF

# Simple QML slideshow
cat > /etc/calamares/branding/linksos/show.qml << 'EOF'
import QtQuick 2.0

Page {
    id: slide
    anchors.fill: parent

    Rectangle {
        anchors.fill: parent
        color: "#0d1117"

        Text {
            anchors.centerIn: parent
            text: "LinkSOS Linux"
            font.pixelSize: 48
            font.bold: true
            color: "#58a6ff"
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: parent.height * 0.65
            text: "Modern. Lightweight. Gaming-Ready."
            font.pixelSize: 24
            color: "#c9d1d9"
        }
    }
}
EOF

# Create placeholder branding images (empty PNGs are OK for now)
touch /etc/calamares/branding/linksos/logo.png
touch /etc/calamares/branding/linksos/icon.png

# ==============================================================================
# 8. HYPERLAND CONFIGURATION
# ==============================================================================

echo "==> [LinkSOS] Configuring Hyprland..."

mkdir -p /etc/hypr

cat > /etc/hypr/hyprland.conf << 'HYPRCONF'
# ╔══════════════════════════════════════════════════════════════╗
# ║                    LinkSOS - Hyprland Config                 ║
# ║     Modern Windows 11 / macOS Hybrid Desktop Experience     ║
# ╚══════════════════════════════════════════════════════════════╝

monitor = , preferred, auto, 1

env = XCURSOR_THEME,Adwaita
env = XCURSOR_SIZE,24
env = QT_QPA_PLATFORM,wayland;xcb
env = QT_WAYLAND_DISABLE_WINDOWDECORATION,1
env = QT_AUTO_SCREEN_SCALE_FACTOR,1
env = GDK_BACKEND,wayland
env = XDG_CURRENT_DESKTOP,Hyprland
env = XDG_SESSION_TYPE,wayland
env = XDG_SESSION_DESKTOP,Hyprland
env = SDL_VIDEODRIVER,wayland
env = CLUTTER_BACKEND,wayland
env = _JAVA_AWT_WM_NONREPARENTING,1

exec-once = waybar
exec-once = dunst
exec-once = swaybg -i /usr/share/wallpapers/linksos/default.png -m fill 2>/dev/null || swaybg -c "#0d1117" -m fill
exec-once = /usr/lib/polkit-kde-agent
exec-once = pipewire
exec-once = pipewire-pulse
exec-once = wireplumber
exec-once = nm-applet --indicator
exec-once = blueman-applet
exec-once = dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP

input {
    kb_layout = us
    follow_mouse = 1
    sensitivity = 0
    accel_profile = flat
    numlock_by_default = true

    touchpad {
        natural_scroll = true
        disable_while_typing = true
        tap-to-click = true
    }
}

gestures {
    workspace_swipe = true
    workspace_swipe_fingers = 3
    workspace_swipe_invert = false
}

general {
    gaps_in = 4
    gaps_out = 8
    border_size = 2
    col.active_border = rgba(58a6ffff) rgba(1f6febff) 45deg
    col.inactive_border = rgba(30363dff)
    layout = dwindle
}

decoration {
    rounding = 12
    blur {
        enabled = true
        size = 6
        passes = 3
        new_optimizations = true
        xray = true
    }
    drop_shadow = true
    shadow_range = 20
    shadow_render_power = 3
    col.shadow = rgba(0d1117cc)
    dim_inactive = true
    dim_strength = 0.05
}

animations {
    enabled = true
    bezier = smooth, 0.25, 0.1, 0.25, 1.0

    animation = windows, 1, 5, smooth
    animation = windowsIn, 1, 5, smooth, popin 80%
    animation = windowsOut, 1, 5, smooth, popin 80%
    animation = fade, 1, 6, smooth
    animation = workspaces, 1, 6, smooth
}

dwindle {
    pseudotile = true
    preserve_split = true
}

misc {
    vfr = true
    mouse_move_enables_dpms = true
    key_press_enables_dpms = true
    disable_splash_rendering = true
    enable_swallow = true
    swallow_regex = ^(konsole)$
}

# Window rules
windowrule = float, ^(pavucontrol)$
windowrule = float, ^(nm-connection-editor)$
windowrule = float, ^(blueman-manager)$
windowrule = float, ^(calamares)$
windowrule = float, ^(lutris)$
windowrule = fullscreen, ^(steam_app_)

# Keybindings
$mainMod = SUPER

bind = $mainMod, Return, exec, konsole
bind = $mainMod, Q, killactive
bind = $mainMod, M, exit
bind = $mainMod, E, exec, dolphin
bind = $mainMod, Space, exec, rofi -show drun -show-icons
bind = $mainMod, F, fullscreen
bind = $mainMod, V, togglefloating
bind = $mainMod, B, exec, brave 2>/dev/null || firefox
bind = $mainMod, G, exec, lutris 2>/dev/null || steam
bind = $mainMod, L, exec, swaylock -c 0d1117
bind = , Print, exec, grim -g "$(slurp)" ~/Pictures/screenshot-$(date +%Y%m%d_%H%M%S).png
bind = $mainMod, Print, exec, grim ~/Pictures/screenshot-$(date +%Y%m%d_%H%M%S).png

bind = $mainMod, h, movefocus, l
bind = $mainMod, l, movefocus, r
bind = $mainMod, k, movefocus, u
bind = $mainMod, j, movefocus, d

bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5
bind = $mainMod, 6, workspace, 6
bind = $mainMod, 7, workspace, 7
bind = $mainMod, 8, workspace, 8
bind = $mainMod, 9, workspace, 9
bind = $mainMod, 0, workspace, 10

bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5
bind = $mainMod SHIFT, 6, movetoworkspace, 6
bind = $mainMod SHIFT, 7, movetoworkspace, 7
bind = $mainMod SHIFT, 8, movetoworkspace, 8
bind = $mainMod SHIFT, 9, movetoworkspace, 9
bind = $mainMod SHIFT, 0, movetoworkspace, 10

bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow
HYPRCONF

# ==============================================================================
# 9. WAYBAR CONFIGURATION
# ==============================================================================

echo "==> [LinkSOS] Configuring Waybar..."

mkdir -p /etc/waybar

cat > /etc/waybar/config << 'WAYBAREOF'
{
    "layer": "top",
    "position": "bottom",
    "height": 44,
    "spacing": 0,

    "modules-left": ["wlr/taskbar", "hyprland/workspaces"],
    "modules-center": ["clock"],
    "modules-right": ["tray", "pulseaudio", "network", "bluetooth", "battery", "custom/power"],

    "hyprland/workspaces": {
        "format": "{icon}",
        "format-icons": {
            "1": "一",
            "2": "二",
            "3": "三",
            "4": "四",
            "5": "五"
        },
        "persistent-workspaces": { "*": 5 }
    },

    "wlr/taskbar": {
        "format": "{icon}",
        "icon-size": 22,
        "tooltip-format": "{title}",
        "on-click": "activate",
        "on-click-middle": "close"
    },

    "clock": {
        "format": "  {:%H:%M}",
        "format-alt": "  {:%A, %B %d, %Y}"
    },

    "pulseaudio": {
        "format": "{icon} {volume}%",
        "format-muted": "  Muted",
        "format-icons": { "default": ["", "", ""] },
        "on-click": "pavucontrol"
    },

    "network": {
        "format-wifi": "  {essid}",
        "format-ethernet": "  {ipaddr}",
        "format-disconnected": "  Disconnected",
        "on-click": "nm-connection-editor"
    },

    "bluetooth": {
        "format": " {status}",
        "format-connected": " {device_alias}",
        "on-click": "blueman-manager"
    },

    "battery": {
        "format": "{icon} {capacity}%",
        "format-charging": "  {capacity}%",
        "format-icons": ["", "", "", "", ""]
    },

    "tray": { "spacing": 8, "icon-size": 18 },

    "custom/power": {
        "format": " ",
        "on-click": "rofi -show power-menu -modi power-menu:rofi-power-menu 2>/dev/null || true"
    }
}
WAYBAREOF

cat > /etc/waybar/style.css << 'WAYBARCSS'
/* LinkSOS Waybar - Windows 11/macOS Hybrid Dark Theme */

* {
    font-family: "Noto Sans", "JetBrains Mono", "Font Awesome 6 Free";
    font-size: 13px;
    border: none;
    border-radius: 0;
    min-height: 0;
    margin: 0;
    padding: 0;
}

window#waybar {
    background: rgba(13, 17, 23, 0.85);
    border-top: 1px solid rgba(48, 54, 61, 0.5);
    color: #c9d1d9;
}

tooltip {
    background: rgba(13, 17, 23, 0.95);
    border: 1px solid rgba(88, 166, 255, 0.3);
    border-radius: 12px;
}

#workspaces, #taskbar, #clock, #tray,
#pulseaudio, #network, #bluetooth, #battery, #custom-power {
    padding: 0 12px;
    margin: 4px 2px;
    border-radius: 8px;
    background: rgba(22, 27, 34, 0.6);
}

#workspaces button {
    padding: 4px 8px;
    color: #8b949e;
    background: transparent;
    border-radius: 6px;
}

#workspaces button.active {
    color: #58a6ff;
    background: rgba(88, 166, 255, 0.15);
}

#taskbar button {
    padding: 4px 8px;
    color: #8b949e;
    background: transparent;
    border-radius: 6px;
}

#taskbar button.active {
    color: #58a6ff;
    background: rgba(88, 166, 255, 0.15);
    border-bottom: 2px solid #58a6ff;
}

#clock { color: #c9d1d9; font-weight: 600; padding: 0 16px; }
#pulseaudio { color: #c9d1d9; }
#pulseaudio.muted { color: #8b949e; }
#network { color: #c9d1d9; }
#network.disconnected { color: #f85149; }
#bluetooth { color: #79c0ff; }
#battery { color: #c9d1d9; }
#battery.warning { color: #d29922; }
#battery.critical { color: #f85149; }
#custom-power { color: #f85149; padding: 0 14px; }
WAYBARCSS

# ==============================================================================
# 10. DUNST CONFIGURATION
# ==============================================================================

echo "==> [LinkSOS] Configuring Dunst..."

mkdir -p /etc/skel/.config/dunst

cat > /etc/skel/.config/dunst/dunstrc << 'DUNSTEOF'
[global]
    monitor = 0
    follow = mouse
    width = 360
    origin = top-right
    offset = "15x15"
    notification_limit = 5
    padding = 12
    horizontal_padding = 12
    frame_width = 1
    frame_color = "#30363d"
    font = Noto Sans 11
    format = "<b>%s</b>\n%b"
    alignment = left
    icon_position = left
    min_icon_size = 32
    max_icon_size = 64
    corner_radius = 12

[urgency_low]
    background = "#161b22"
    foreground = "#8b949e"
    timeout = 5

[urgency_normal]
    background = "#161b22"
    foreground = "#c9d1d9"
    timeout = 10

[urgency_critical]
    background = "#161b22"
    foreground = "#f85149"
    frame_color = "#f85149"
    timeout = 0
DUNSTEOF

# ==============================================================================
# 11. ROFI CONFIGURATION
# ==============================================================================

echo "==> [LinkSOS] Configuring Rofi..."

mkdir -p /etc/skel/.config/rofi

cat > /etc/skel/.config/rofi/config.rasi << 'ROFEOF'
configuration {
    modi: "drun,run,window";
    font: "Noto Sans 12";
    show-icons: true;
    icon-theme: "Tela-blue-dark";
    drun-display-format: "{name}";
    matching: "fuzzy";
    display-drun: "  Apps";
    display-run: "  Run";
}

@theme "/dev/null"

* {
    bg: #0d1117ee;
    bg-alt: #161b22ee;
    fg: #c9d1d9;
    fg-alt: #8b949e;
    accent: #58a6ff;
    border: #30363d;
}

window {
    background-color: @bg;
    border: 1px solid @border;
    border-radius: 12px;
    padding: 16px;
    width: 600px;
}

inputbar {
    children: ["prompt", "entry"];
    background-color: @bg-alt;
    border-radius: 8px;
    padding: 12px;
}

prompt { color: @accent; }

entry {
    color: @fg;
    placeholder: "Search...";
}

element {
    padding: 10px;
    border-radius: 8px;
}

element selected {
    background-color: rgba(88, 166, 255, 0.15);
    color: @accent;
}

element-icon { size: 28px; }
ROFEOF

# ==============================================================================
# 12. GTK THEME
# ==============================================================================

echo "==> [LinkSOS] Configuring GTK theme..."

mkdir -p /etc/skel/.config/gtk-3.0

cat > /etc/skel/.config/gtk-3.0/settings.ini << 'GTKEOF'
[Settings]
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Tela-blue-dark
gtk-font-name=Noto Sans 11
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=24
gtk-application-prefer-dark-theme=1
GTKEOF

# ==============================================================================
# 13. COPY DESKTOP CONFIGS TO SKEL
# ==============================================================================

echo "==> [LinkSOS] Copying configs to skel directory..."

mkdir -p /etc/skel/.config/hypr
mkdir -p /etc/skel/.config/waybar

cp /etc/hypr/hyprland.conf /etc/skel/.config/hypr/hyprland.conf || true
cp /etc/waybar/config /etc/skel/.config/waybar/config || true
cp /etc/waybar/style.css /etc/skel/.config/waybar/style.css || true

# ==============================================================================
# 14. CUSTOM SCRIPTS
# ==============================================================================

echo "==> [LinkSOS] Creating custom utility scripts..."

cat > /usr/local/bin/linksos-first-run << 'FIRSTRUNEOF'
#!/usr/bin/env bash
# LinkSOS First-Run Wizard

MARKER="$HOME/.config/linksos/.first-run-done"

if [ -f "$MARKER" ]; then
    exit 0
fi

mkdir -p "$HOME/.config/linksos"

notify-send "Welcome to LinkSOS!" "A modern, lightweight, gaming-ready desktop experience." 2>/dev/null || true

# Detect GPU and install appropriate drivers
if lspci | grep -qi nvidia; then
    sudo pacman -S --noconfirm --needed nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings 2>/dev/null || true
elif lspci | grep -qi amd; then
    sudo pacman -S --noconfirm --needed mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon 2>/dev/null || true
elif lspci | grep -qi intel; then
    sudo pacman -S --noconfirm --needed mesa lib32-mesa vulkan-intel lib32-vulkan-intel 2>/dev/null || true
fi

date > "$MARKER"
echo "==> [LinkSOS] First-run setup complete!"
FIRSTRUNEOF
chmod +x /usr/local/bin/linksos-first-run

cat > /usr/local/bin/linksos-setup-gaming << 'GAMINGEOF'
#!/usr/bin/env bash
# LinkSOS Gaming Setup Script

echo "==> [LinkSOS] Setting up gaming environment..."

# Detect GPU
if lspci | grep -qi nvidia; then
    pacman -S --noconfirm --needed nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings 2>/dev/null || true
elif lspci | grep -qi amd; then
    pacman -S --noconfirm --needed mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon 2>/dev/null || true
elif lspci | grep -qi intel; then
    pacman -S --noconfirm --needed mesa lib32-mesa vulkan-intel lib32-vulkan-intel 2>/dev/null || true
fi

# Install gaming tools
pacman -S --noconfirm --needed \
    wine wine-mono wine-gecko winetricks \
    steam lutris \
    mangohud lib32-mangohud \
    gamemode lib32-gamemode \
    gamescope protontricks \
    2>/dev/null || true

echo "==> [LinkSOS] Gaming setup complete!"
GAMINGEOF
chmod +x /usr/local/bin/linksos-setup-gaming

cat > /usr/local/bin/linksos-app-center << 'APPCENTEREOF'
#!/usr/bin/env bash
# LinkSOS App Center - Simple graphical application manager

notify-send "LinkSOS App Center" "Opening application center..." 2>/dev/null || true

ACTION=$(zenity --list --title="LinkSOS App Center" --text="What would you like to do?" \
    --column="Action" --column="Description" \
    "install" "Install new applications" \
    "update" "Update your system" \
    "search" "Search for packages" \
    "flatpak" "Browse Flathub (web)" 2>/dev/null || echo "cancel")

case "$ACTION" in
    install)
        PKG=$(zenity --entry --title="Install Package" --text="Enter package name:" 2>/dev/null || echo "")
        if [ -n "$PKG" ]; then
            konsole -e bash -c "sudo pacman -S --noconfirm $PKG && echo 'Installation complete!' && read" 2>/dev/null || true
        fi
        ;;
    update)
        konsole -e bash -c "sudo pacman -Syu && echo 'Update complete!' && read" 2>/dev/null || true
        ;;
    search)
        PKG=$(zenity --entry --title="Search Packages" --text="Enter search term:" 2>/dev/null || echo "")
        if [ -n "$PKG" ]; then
            konsole -e bash -c "pacman -Ss $PKG && read" 2>/dev/null || true
        fi
        ;;
    flatpak)
        xdg-open "https://flathub.org" 2>/dev/null || brave https://flathub.org 2>/dev/null || true
        ;;
esac
APPCENTEREOF
chmod +x /usr/local/bin/linksos-app-center

# ==============================================================================
# 15. SYSTEMD SERVICES (NOW create them, THEN enable)
# ==============================================================================

echo "==> [LinkSOS] Creating systemd services..."

mkdir -p /etc/systemd/system

cat > /etc/systemd/system/linksos-first-run.service << 'EOF'
[Unit]
Description=LinkSOS First-Run Wizard
After=sddm.service

[Service]
Type=oneshot
User=linksos
Environment=DISPLAY=:0
Environment=WAYLAND_DISPLAY=wayland-1
ExecStart=/usr/local/bin/linksos-first-run
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/linksos-gaming-setup.service << 'EOF'
[Unit]
Description=LinkSOS Gaming Environment Setup
After=NetworkManager.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/linksos-setup-gaming
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# NOW enable the services (after creating them!)
systemctl enable linksos-first-run.service || true
systemctl enable linksos-gaming-setup.service || true

# ==============================================================================
# 16. SDDM THEME
# ==============================================================================

echo "==> [LinkSOS] Creating SDDM theme..."

mkdir -p /usr/share/sddm/themes/linksos

cat > /usr/share/sddm/themes/linksos/metadata.desktop << 'EOF'
[SddmGreeterTheme]
Name=LinkSOS
Description=LinkSOS SDDM Login Theme
Version=1.0
MainScript=Main.qml
ConfigFile=theme.conf
Theme-Id=linksos
Theme-API=2
EOF

cat > /usr/share/sddm/themes/linksos/theme.conf << 'EOF'
[General]
background=
type=color
color=#0d1117
font=Noto Sans
fontSize=12
foregroundColor=#c9d1d9
EOF

cat > /usr/share/sddm/themes/linksos/Main.qml << 'SDDMQML'
import QtQuick 2.15
import QtQuick.Controls 2.15
import SddmComponents 2.0

Rectangle {
    id: root
    color: "#0d1117"

    Rectangle {
        width: 400
        height: 300
        radius: 16
        color: "#161b22"
        border.color: "#30363d"
        anchors.centerIn: parent

        Column {
            anchors.centerIn: parent
            spacing: 16

            Text {
                text: "LinkSOS"
                font.pixelSize: 36
                font.bold: true
                color: "#58a6ff"
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "Modern. Lightweight. Gaming-Ready."
                font.pixelSize: 14
                color: "#8b949e"
                anchors.horizontalCenter: parent.horizontalCenter
            }

            TextField {
                id: username
                width: 300
                height: 44
                placeholderText: "Username"
                color: "#c9d1d9"
                background: Rectangle { color: "#0d1117"; radius: 8; border.color: "#30363d" }
            }

            TextField {
                id: password
                width: 300
                height: 44
                placeholderText: "Password"
                echoMode: TextInput.Password
                color: "#c9d1d9"
                background: Rectangle { color: "#0d1117"; radius: 8; border.color: "#30363d" }
                Keys.onReturnPressed: sddm.login(username.text, password.text)
            }

            Button {
                id: loginButton
                width: 300
                height: 44
                background: Rectangle {
                    color: loginButton.pressed ? "#1f6feb" : "#58a6ff"
                    radius: 8
                }
                contentItem: Text {
                    text: "Sign In"
                    color: "#ffffff"
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: sddm.login(username.text, password.text)
            }
        }
    }
}
SDDMQML

# ==============================================================================
# 17. WALLPAPERS
# ==============================================================================

echo "==> [LinkSOS] Setting up wallpapers..."

mkdir -p /usr/share/wallpapers/linksos

# Try creating wallpaper with ImageMagick (may not be available in chroot)
if command -v convert &> /dev/null; then
    convert -size 1920x1080 gradient:'#0d1117'-'#1a1f2e' \
        /usr/share/wallpapers/linksos/default.png 2>/dev/null || true
fi

# Fallback: create a 1x1 dark PNG
if [ ! -f /usr/share/wallpapers/linksos/default.png ] || [ ! -s /usr/share/wallpapers/linksos/default.png ]; then
    python3 -c "
import struct, zlib
def create_png(w, h, r, g, b):
    raw = b''.join(b'\x00' + bytes([r,g,b]) * w for _ in range(h))
    return b'\x89PNG\r\n\x1a\n' + struct.pack('>I', 13) + b'IHDR' + struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0) + struct.pack('>I', zlib.crc32(b'IHDR' + struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)) & 0xffffffff) + struct.pack('>I', len(raw)) + b'IDAT' + zlib.compress(raw) + struct.pack('>I', zlib.crc32(b'IDAT' + zlib.compress(raw)) & 0xffffffff) + b'\x00\x00\x00\x00IEND\xaeB\x60\x82'
with open('/usr/share/wallpapers/linksos/default.png', 'wb') as f:
    f.write(create_png(1, 1, 13, 17, 23))
" 2>/dev/null || true
fi

# ==============================================================================
# 18. LOCALE
# ==============================================================================

echo "==> [LinkSOS] Configuring locale..."

sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/#zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/#ja_JP.UTF-8 UTF-8/ja_JP.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/#de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/#fr_FR.UTF-8 UTF-8/fr_FR.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/#es_ES.UTF-8 UTF-8/es_ES.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/#pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/' /etc/locale.gen
locale-gen || true

echo "LANG=en_US.UTF-8" > /etc/locale.conf

# ==============================================================================
# 19. DESKTOP SHORTCUTS & DEFAULT DIRS
# ==============================================================================

echo "==> [LinkSOS] Creating desktop shortcuts..."

mkdir -p /etc/skel/Desktop
mkdir -p /etc/skel/Documents
mkdir -p /etc/skel/Downloads
mkdir -p /etc/skel/Music
mkdir -p /etc/skel/Pictures
mkdir -p /etc/skel/Videos
mkdir -p /etc/skel/Games

cat > /etc/skel/Desktop/calamares.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Install LinkSOS
GenericName=System Installer
Exec=/usr/bin/calamares
Icon=calamares
Terminal=false
Categories=System;
EOF
chmod +x /etc/skel/Desktop/calamares.desktop

cat > /etc/skel/Desktop/app-center.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=App Center
GenericName=Application Manager
Exec=/usr/local/bin/linksos-app-center
Icon=system-software-install
Terminal=false
Categories=System;
EOF
chmod +x /etc/skel/Desktop/app-center.desktop

# ==============================================================================
# 20. FINAL CLEANUP
# ==============================================================================

echo "==> [LinkSOS] Final cleanup..."

# Copy skel to live user home
if [ -d /home/linksos ]; then
    cp -a /etc/skel/. /home/linksos/ || true
    chown -R linksos:linksos /home/linksos || true
fi

# Clean pacman cache to reduce ISO size
yes | pacman -Scc 2>/dev/null || true

# Remove orphan packages
pacman -Rns --noconfirm $(pacman -Qdtq) 2>/dev/null || true

# Set permissions
chmod 0750 /root || true
chmod 0400 /etc/shadow || true
chmod 0400 /etc/gshadow || true

# Ensure pacman.conf has archlinuxcn for the installed system too
if ! grep -q "archlinuxcn" /etc/pacman.conf; then
    cat >> /etc/pacman.conf << 'REPOEOF'
[archlinuxcn]
Server = https://repo.archlinuxcn.org/$arch
SigLevel = Optional TrustAll
REPOEOF
fi

echo "==> [LinkSOS] airootfs customization COMPLETE!"
