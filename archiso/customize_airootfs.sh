#!/usr/bin/env bash
# ==============================================================================
# LinkSOS - customize_airootfs.sh
# Post-install customization script for the live system chroot
# Runs INSIDE the airootfs chroot during archiso build
# ==============================================================================

set -euo pipefail

echo "==> [LinkSOS] Starting airootfs customization..."

# ==============================================================================
# 1. SYSTEM CONFIGURATION
# ==============================================================================

echo "==> [LinkSOS] Configuring system services..."

# Enable essential services
systemctl enable NetworkManager.service
systemctl enable sddm.service
systemctl enable bluetooth.service
systemctl enable cups.service
systemctl enable firewalld.service
systemctl enable power-profiles-daemon.service
systemctl enable systemd-resolved.service
systemctl enable systemd-timesyncd.service
systemctl enable reflector.service
systemctl enable avahi-daemon.service

# Enable LinkSOS custom services
systemctl enable linksos-first-run.service
systemctl enable linksos-gaming-setup.service

# Disable unnecessary services for minimal RAM
systemctl disable lvm2-monitor.service 2>/dev/null || true
systemctl disable lvm2-lvmetad.service 2>/dev/null || true

# ==============================================================================
# 2. USER SETUP
# ==============================================================================

echo "==> [LinkSOS] Setting up users..."

# Create live user
useradd -m -G wheel,audio,video,optical,storage,games,input,lp,scanner,plugdev -s /bin/bash linksos 2>/dev/null || true

# Set live user password (empty for live session)
echo "linksos:" | chpasswd
echo "root:linksos" | chpasswd

# Allow wheel group to sudo without password (for live session)
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/99-wheel-nopasswd
chmod 0440 /etc/sudoers.d/99-wheel-nopasswd

# Copy skel to live user home
cp -a /etc/skel/. /home/linksos/
chown -R linksos:linksos /home/linksos

# ==============================================================================
# 3. KERNEL PARAMETERS & OPTIMIZATION
# ==============================================================================

echo "==> [LinkSOS] Optimizing kernel parameters..."

# Create sysctl optimization file
cat > /etc/sysctl.d/99-linksos-optimize.conf << 'EOF'
# Minimal RAM usage optimizations
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_ratio=15
vm.dirty_background_ratio=5
vm.min_free_kbytes=65536

# Gaming optimizations
kernel.sched_autogroup_enabled=1
kernel.sched_cfs_bandwidth_slice_us=3000

# Network optimizations
net.core.somaxconn=1024
net.ipv4.tcp_fastopen=3

# Security
kernel.kptr_restrict=2
kernel.dmesg_restrict=1
EOF

# ==============================================================================
# 4. PACMAN CONFIGURATION FOR INSTALLED SYSTEM
# ==============================================================================

echo "==> [LinkSOS] Configuring pacman for installed system..."

# Add archlinuxcn repo to installed system pacman.conf
if ! grep -q "archlinuxcn" /etc/pacman.conf; then
    cat >> /etc/pacman.conf << 'EOF'

[archlinuxcn]
Server = https://repo.archlinuxcn.org/$arch
SigLevel = Optional TrustAll
EOF
fi

# ==============================================================================
# 5. SDDM CONFIGURATION
# ==============================================================================

echo "==> [LinkSOS] Configuring SDDM login manager..."

# Create SDDM config
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
RebootCommand=/usr/bin/systemctl reboot
HaltCommand=/usr/bin/systemctl poweroff
EOF

# ==============================================================================
# 6. REFLECTOR CONFIGURATION
# ==============================================================================

echo "==> [LinkSOS] Configuring mirror auto-update..."

cat > /etc/xdg/reflector/reflector.conf << 'EOF'
--save /etc/pacman.d/mirrorlist
--protocol https
--country "United States,Germany,France,United Kingdom,Netherlands,Japan,Singapore"
--latest 20
--sort rate
EOF

# ==============================================================================
# 7. CALAMARES CONFIGURATION
# ==============================================================================

echo "==> [LinkSOS] Configuring Calamares installer..."

# Calamares settings.conf
cat > /etc/calamares/settings.conf << 'CALAMARES_EOF'
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
    - linksos-postinstall
    - cleanup
  - show:
    - finished
prompt-install: false
dont-chroot: false
oem-setup: false
disable-cancel: false
disable-cancel-during-exec: true
CALAMARES_EOF

# Calamares partition module
cat > /etc/calamares/modules/partition.conf << 'CALAMARES_EOF'
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
partitionChoices:
  - storage
  - device
  - installChoice
  - manualPartitioning
CALAMARES_EOF

# Calamares unpackfs module
cat > /etc/calamares/modules/unpackfs.conf << 'CALAMARES_EOF'
---
unpack:
  - source: "/run/archiso/bootmnt/arch/x86_64/airootfs.sfs"
    sourcefs: "squashfs"
    destination: ""
CALAMARES_EOF

# Calamares users module
cat > /etc/calamares/modules/users.conf << 'CALAMARES_EOF'
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
  - plugdev
  - network
doAutologin: false
doReusePassword: true
passwordRequirements:
  minLength: 0
  maxLength: -1
userShell: /bin/bash
setHostname: EtcFile
CALAMARES_EOF

# Calamares services module
cat > /etc/calamares/modules/services.conf << 'CALAMARES_EOF'
---
services:
  enable:
    - NetworkManager
    - sddm
    - bluetooth
    - cups
    - firewalld
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
CALAMARES_EOF

# Calamares bootloader module
cat > /etc/calamares/modules/bootloader.conf << 'CALAMARES_EOF'
---
efiBootLoader: "grub"
kernel: "/boot/vmlinuz-linux-zen"
img: "/boot/initramfs-linux-zen.img"
fallback: "/boot/initramfs-linux-zen-fallback.img"
kernelParam: ["quiet", "splash", "loglevel=3", "rd.systemd.show_status=auto", "rd.udev.log_level=3", "mitigations=off", "nowatchdog", "nvidia-drm.modeset=1"]
grubInstall: "grub-install"
grubMkconfig: "grub-mkconfig"
grubCfg: "/boot/grub/grub.cfg"
CALAMARES_EOF

# Calamares machineid module
cat > /etc/calamares/modules/machineid.conf << 'CALAMARES_EOF'
---
systemd: true
dbus: true
symlink: true
CALAMARES_EOF

# Calamares mount module
cat > /etc/calamares/modules/mount.conf << 'CALAMARES_EOF'
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
  - device: /dev/pts
    fs: devpts
    mountPoint: /dev/pts
  - device: tmpfs
    fs: tmpfs
    mountPoint: /run
  - device: /run/archiso/bootmnt
    fs: none
    mountPoint: /mnt/boot
    options: [bind]
CALAMARES_EOF

# Calamares fstab module
cat > /etc/calamares/modules/fstab.conf << 'CALAMARES_EOF'
---
mountOptions:
  default: defaults,noatime
  btrfs: defaults,noatime,compress=zstd
ssdExtraMountOptions:
  ext4: discard
  btrfs: discard,compress=zstd
  xfs: discard
crypttabOptions: luks
CALAMARES_EOF

# Calamares locale module
cat > /etc/calamares/modules/locale.conf << 'CALAMARES_EOF'
---
region: "America"
zone: "New_York"
localeGenPath: "/etc/locale.gen"
CALAMARES_EOF

# Calamares keyboard module
cat > /etc/calamares/modules/keyboard.conf << 'CALAMARES_EOF'
---
keyboardModels: []
keyboardLayouts:
  - us
CALAMARES_EOF

# Calamares networkcfg module
cat > /etc/calamares/modules/networkcfg.conf << 'CALAMARES_EOF'
---
systemdNetworkd: false
CALAMARES_EOF

# Calamares hwclock module
cat > /etc/calamares/modules/hwclock.conf << 'CALAMARES_EOF'
---
localtime: true
CALAMARES_EOF

# Calamares grubcfg module
cat > /etc/calamares/modules/grubcfg.conf << 'CALAMARES_EOF'
---
overwrite: false
keepDistributor: true
CALAMARES_EOF

# Calamares welcome module
cat > /etc/calamares/modules/welcome.conf << 'CALAMARES_EOF'
---
showSupportUrl: true
showKnownIssuesUrl: true
showReleaseNotesUrl: false
requiredStorage: 20
requiredRam: 2.0
internetCheckUrl: "https://archlinux.org"
CALAMARES_EOF

# Calamares finished module
cat > /etc/calamares/modules/finished.conf << 'CALAMARES_EOF'
---
restartNowMode: user-unchecked
restartNowCommand: "systemctl -i reboot"
CALAMARES_EOF

# Calamares summary module
cat > /etc/calamares/modules/summary.conf << 'CALAMARES_EOF'
---
show: true
CALAMARES_EOF

# LinkSOS custom post-install module
cat > /etc/calamares/modules/linksos-postinstall.conf << 'CALAMARES_EOF'
---
dontChroot: false
script:
  - "cp /etc/calamares/linksos-postinstall.sh /tmp/linksos-postinstall.sh && chmod +x /tmp/linksos-postinstall.sh && /tmp/linksos-postinstall.sh"
CALAMARES_EOF

# LinkSOS post-install script (runs in chroot after install)
cat > /etc/calamares/linksos-postinstall.sh << 'POSTINSTALL_EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "==> [LinkSOS Post-Install] Setting up the installed system..."

# Remove live user
userdel -r linksos 2>/dev/null || true

# Remove autologin
rm -f /etc/sddm.conf.d/linksos.conf 2>/dev/null || true

# Create proper SDDM config for installed system
cat > /etc/sddm.conf.d/linksos-installed.conf << 'SDDM_INSTALLED'
[Theme]
Current=linksos
CursorTheme=Adwaita
Font=Noto Sans

[General]
Numlock=on
SDDM_INSTALLED

# Remove live session sudoers
rm -f /etc/sudoers.d/99-wheel-nopasswd

# Enable proper sudo for wheel group
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/10-wheel
chmod 0440 /etc/sudoers.d/10-wheel

# Set up pacman
pacman-key --init
pacman-key --populate archlinux

# Add archlinuxcn repo
if ! grep -q "archlinuxcn" /etc/pacman.conf; then
    cat >> /etc/pacman.conf << 'REPO_EOF'

[archlinuxcn]
Server = https://repo.archlinuxcn.org/$arch
SigLevel = Optional TrustAll
REPO_EOF
fi

# Install NVIDIA drivers if NVIDIA GPU detected
if lspci | grep -i nvidia > /dev/null 2>&1; then
    echo "==> [LinkSOS] NVIDIA GPU detected, ensuring drivers are installed..."
    pacman -S --noconfirm --needed nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings 2>/dev/null || true
    dkms autoinstall 2>/dev/null || true
fi

# Optimize initramfs
sed -i 's/^MODULES=(.*/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf 2>/dev/null || true
sed -i 's/^COMPRESSION="zstd"/COMPRESSION="zstd"\nCOMPRESSION_OPTIONS=(-T0)/' /etc/mkinitcpio.conf 2>/dev/null || true
mkinitcpio -P 2>/dev/null || true

# Rebuild GRUB
grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || true

echo "==> [LinkSOS Post-Install] Complete!"
POSTINSTALL_EOF
chmod +x /etc/calamares/linksos-postinstall.sh

# ==============================================================================
# 8. CALAMARES BRANDING
# ==============================================================================

echo "==> [LinkSOS] Creating Calamares branding..."

cat > /etc/calamares/branding/linksos/branding.desc << 'BRANDING_EOF'
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
  knownIssuesUrl: ""
  releaseNotesUrl: ""
images:
  productLogo: "logo.png"
  productIcon: "icon.png"
  productWelcome: "welcome.png"
slideshow: "show.qml"
style:
  sidebarBackground: "#0d1117"
  sidebarText: "#c9d1d9"
  sidebarTextSelect: "#58a6ff"
  sidebarTextHighlight: "#1f6feb"
BRANDING_EOF

# Create a simple QML slideshow
cat > /etc/calamares/branding/linksos/show.qml << 'QML_EOF'
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

    Timer {
        interval: 5000
        running: true
        repeat: true
    }
}
QML_EOF

# Create placeholder logo/icon (simple SVG)
cat > /etc/calamares/branding/linksos/logo.png << 'EOF'
EOF

# ==============================================================================
# 9. HYPERLAND CONFIGURATION
# ==============================================================================

echo "==> [LinkSOS] Configuring Hyprland..."

# System-wide Hyprland config (fallback if no user config)
cat > /etc/hypr/hyprland.conf << 'HYPR_EOF'
# ╔══════════════════════════════════════════════════════════════╗
# ║                    LinkSOS - Hyprland Config                 ║
# ║     Modern Windows 11 / macOS Hybrid Desktop Experience     ║
# ╚══════════════════════════════════════════════════════════════╝

# ── MONITOR ────────────────────────────────────────────────────
monitor = , preferred, auto, 1
# For HiDPI: monitor = , preferred, auto, 1.5

# ── ENVIRONMENT VARIABLES ─────────────────────────────────────
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
env = WLR_NO_HARDWARE_CURSORS,1
env = NVIDIA_DRIVER_CAPABILITIES,all

# ── STARTUP APPLICATIONS ──────────────────────────────────────
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
exec-once = systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
exec-once = xdg-mime default org.kde.dolphin.desktop inode/directory
exec-once = linksos-first-run 2>/dev/null || true

# ── INPUT ──────────────────────────────────────────────────────
input {
    kb_layout = us
    kb_variant =
    kb_model =
    kb_options =
    kb_rules =

    follow_mouse = 1
    sensitivity = 0
    accel_profile = flat
    numlock_by_default = true

    touchpad {
        natural_scroll = true
        disable_while_typing = true
        tap-to-click = true
        clickfinger_behavior = true
        middle_button_emulation = true
    }
}

# ── GESTURES ──────────────────────────────────────────────────
gestures {
    workspace_swipe = true
    workspace_swipe_fingers = 3
    workspace_swipe_distance = 300
    workspace_swipe_invert = false
    workspace_swipe_min_speed_to_force = 30
    workspace_swipe_cancel_ratio = 0.5
    workspace_swipe_create_new = true
    workspace_swipe_forever = true
}

# ── GENERAL ───────────────────────────────────────────────────
general {
    gaps_in = 4
    gaps_out = 8
    border_size = 2
    col.active_border = rgba(58a6ffff) rgba(1f6febff) 45deg
    col.inactive_border = rgba(30363dff)
    layout = dwindle
    allow_tearing = false

    snap {
        enabled = true
        window_gap = 15
        monitor_gap = 10
    }
}

# ── DECORATION ────────────────────────────────────────────────
decoration {
    rounding = 12
    blur {
        enabled = true
        size = 6
        passes = 3
        new_optimizations = true
        ignore_opacity = true
        xray = true
    }
    drop_shadow = true
    shadow_range = 20
    shadow_render_power = 3
    col.shadow = rgba(0d1117cc)
    col.shadow_inactive = rgba(0d111766)
    dim_inactive = true
    dim_strength = 0.05
}

# ── ANIMATIONS ────────────────────────────────────────────────
animations {
    enabled = true
    bezier = smooth, 0.25, 0.1, 0.25, 1.0
    bezier = snap, 0.5, 0.0, 0.5, 1.0
    bezier = quick, 0.15, 0.85, 0.3, 1.0

    animation = windows, 1, 5, smooth
    animation = windowsIn, 1, 5, smooth, popin 80%
    animation = windowsOut, 1, 5, smooth, popin 80%
    animation = windowsMove, 1, 4, smooth
    animation = fade, 1, 6, smooth
    animation = fadeIn, 1, 6, smooth
    animation = fadeOut, 1, 6, smooth
    animation = border, 1, 8, smooth
    animation = borderangle, 1, 50, snap, loop
    animation = workspaces, 1, 6, smooth
    animation = specialWorkspace, 1, 6, smooth, slidevert
}

# ── LAYOUTS ───────────────────────────────────────────────────
dwindle {
    pseudotile = true
    preserve_split = true
    smart_split = true
    smart_resizing = true
    force_split = 2
}

# ── MISC ──────────────────────────────────────────────────────
misc {
    vfr = true
    vrr = 0
    mouse_move_enables_dpms = true
    key_press_enables_dpms = true
    disable_splash_rendering = true
    force_default_wallpaper = 0
    enable_swallow = true
    swallow_regex = ^(konsole)$
    focus_on_activate = true
    no_direct_scanout = true
    initial_workspace_tracking = 1
}

# ── WINDOW RULES ──────────────────────────────────────────────
# Floating windows
windowrule = float, ^(org.kde.dolphin)$, title:^(Progress Dialog — Dolphin)$
windowrule = float, ^(org.kde.dolphin)$, title:^(Copy — Dolphin)$
windowrule = float, ^(org.kde.dolphin)$, title:^(Move — Dolphin)$
windowrule = float, ^(org.kde.dolphin)$, title:^(Delete — Dolphin)$
windowrule = float, ^(pavucontrol)$
windowrule = float, ^(nm-connection-editor)$
windowrule = float, ^(blueman-manager)$
windowrule = float, ^(calamares)$
windowrule = float, ^(lutris)$

# Gaming windows
windowrule = fullscreen, ^(steam_app_)
windowrule = fullscreen, ^(osu!)
windowrule = float, ^(steam)$, title:^(Steam)$

# No shadow for screenshots
windowrule = noshadow, ^(screenshot)$

# ── KEYBINDINGS ───────────────────────────────────────────────
# Super key = Windows key
$mainMod = SUPER

# Essential bindings
bind = $mainMod, Return, exec, konsole
bind = $mainMod, Q, killactive
bind = $mainMod, M, exit
bind = $mainMod, E, exec, dolphin
bind = $mainMod, Space, exec, rofi -show drun -show-icons
bind = $mainMod, F, fullscreen
bind = $mainMod, V, togglefloating
bind = $mainMod, R, exec, rofi -show run
bind = $mainMod, P, pseudo
bind = $mainMod, J, togglesplit

# Screenshot
bind = , Print, exec, grim -g "$(slurp)" - | swappy -f - 2>/dev/null || grim -g "$(slurp)" ~/Pictures/screenshot-$(date +%Y%m%d_%H%M%S).png
bind = $mainMod, Print, exec, grim ~/Pictures/screenshot-$(date +%Y%m%d_%H%M%S).png

# Application shortcuts
bind = $mainMod, B, exec, brave 2>/dev/null || firefox
bind = $mainMod, T, exec, konsole
bind = $mainMod, G, exec, lutris 2>/dev/null || steam
bind = $mainMod, L, exec, swaylock -c 0d1117

# System controls
bind = $mainMod Shift, E, exec, wofi --show logout 2>/dev/null || rofi -show power-menu -modi power-menu:rofi-power-menu

# Focus movement
bind = $mainMod, h, movefocus, l
bind = $mainMod, l, movefocus, r
bind = $mainMod, k, movefocus, u
bind = $mainMod, j, movefocus, d

# Switch workspaces
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

# Move active window to workspace
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

# Scroll through workspaces
bind = $mainMod, mouse_down, workspace, e+1
bind = $mainMod, mouse_up, workspace, e-1

# Move/resize windows with mouse
bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow

# Resize with keyboard
bind = $mainMod CTRL, h, resizeactive, -30 0
bind = $mainMod CTRL, l, resizeactive, 30 0
bind = $mainMod CTRL, k, resizeactive, 0 -30
bind = $mainMod CTRL, j, resizeactive, 0 30
HYPR_EOF

# ==============================================================================
# 10. WAYBAR CONFIGURATION (Windows 11 Style)
# ==============================================================================

echo "==> [LinkSOS] Configuring Waybar (Windows 11-style taskbar)..."

# System-wide waybar config
cat > /etc/waybar/config << 'WAYBAR_CONFIG_EOF'
{
    "layer": "top",
    "position": "bottom",
    "height": 44,
    "margin": "0 0 0 0",
    "spacing": 0,

    "modules-left": ["wlr/taskbar", "hyprland/workspaces"],
    "modules-center": ["clock"],
    "modules-right": ["tray", "pulseaudio", "network", "bluetooth", "battery", "custom/power"],

    "hyprland/workspaces": {
        "disable-scroll": false,
        "all-outputs": true,
        "format": "{icon}",
        "format-icons": {
            "1": "一",
            "2": "二",
            "3": "三",
            "4": "四",
            "5": "五",
            "6": "六",
            "7": "七",
            "8": "八",
            "9": "九",
            "10": "十",
            "urgent": "",
            "focused": "",
            "default": ""
        },
        "persistent-workspaces": {
            "*": 5
        }
    },

    "wlr/taskbar": {
        "format": "{icon}",
        "icon-size": 22,
        "tooltip-format": "{title}",
        "on-click": "activate",
        "on-click-middle": "close",
        "app_ids-mapping": {
            "firefox": "firefox",
            "brave": "brave-browser",
            "org.kde.dolphin": "dolphin",
            "org.kde.konsole": "konsole",
            "steam": "steam",
            "lutris": "lutris"
        },
        "ignore-list": [
            "waybar"
        ]
    },

    "clock": {
        "interval": 1,
        "format": "  {:%H:%M}",
        "format-alt": "  {:%A, %B %d, %Y}",
        "tooltip-format": "<tt><small>{calendar}</small></tt>",
        "calendar": {
            "mode": "month",
            "mode-mon-col": 3,
            "weeks-pos": "right",
            "on-scroll": 1,
            "format": {
                "months": "<span color='#58a6ff'><b>{}</b></span>",
                "days": "<span color='#c9d1d9'><b>{}</b></span>",
                "weeks": "<span color='#30363d'><b>W{}</b></span>",
                "weekdays": "<span color='#8b949e'><b>{}</b></span>",
                "today": "<span color='#f85149'><b>{}</b></span>"
            }
        }
    },

    "pulseaudio": {
        "format": "{icon} {volume}%",
        "format-muted": "  Muted",
        "format-icons": {
            "default": ["", "", ""]
        },
        "on-click": "pavucontrol",
        "on-click-right": "pamixer -t"
    },

    "network": {
        "format-wifi": "  {essid}",
        "format-ethernet": "  {ipaddr}",
        "format-disconnected": "  Disconnected",
        "tooltip-format-wifi": "WiFi: {essid} ({signalStrength}%)\nIP: {ipaddr}\nGateway: {gwaddr}",
        "tooltip-format-ethernet": "IP: {ipaddr}\nGateway: {gwaddr}",
        "on-click": "nm-connection-editor"
    },

    "bluetooth": {
        "format": " {status}",
        "format-connected": " {device_alias}",
        "on-click": "blueman-manager"
    },

    "battery": {
        "states": {
            "warning": 30,
            "critical": 15
        },
        "format": "{icon} {capacity}%",
        "format-charging": "  {capacity}%",
        "format-plugged": "  {capacity}%",
        "format-icons": ["", "", "", "", ""]
    },

    "tray": {
        "spacing": 8,
        "icon-size": 18
    },

    "custom/power": {
        "format": " ",
        "on-click": "rofi -show power-menu -modi power-menu:rofi-power-menu 2>/dev/null || wofi --show logout 2>/dev/null || true",
        "tooltip": false
    }
}
WAYBAR_CONFIG_EOF

# Waybar CSS (Windows 11 / macOS hybrid dark theme)
cat > /etc/waybar/style.css << 'WAYBAR_CSS_EOF'
/* ╔══════════════════════════════════════════════════════════════╗
   ║            LinkSOS Waybar - Windows 11/macOS Hybrid         ║
   ╚══════════════════════════════════════════════════════════════╝ */

* {
    font-family: "Noto Sans", "JetBrains Mono", "Font Awesome 6 Free";
    font-size: 13px;
    border: none;
    border-radius: 0;
    min-height: 0;
    padding: 0;
    margin: 0;
}

/* Main bar */
window#waybar {
    background: rgba(13, 17, 23, 0.85);
    border-top: 1px solid rgba(48, 54, 61, 0.5);
    color: #c9d1d9;
}

/* Tooltip styling */
tooltip {
    background: rgba(13, 17, 23, 0.95);
    border: 1px solid rgba(88, 166, 255, 0.3);
    border-radius: 12px;
    padding: 8px 12px;
}

tooltip label {
    color: #c9d1d9;
}

/* Modules */
#workspaces,
#taskbar,
#clock,
#tray,
#pulseaudio,
#network,
#bluetooth,
#battery,
#custom-power {
    padding: 0 12px;
    margin: 4px 2px;
    border-radius: 8px;
    background: rgba(22, 27, 34, 0.6);
}

/* Workspaces */
#workspaces button {
    padding: 4px 8px;
    color: #8b949e;
    background: transparent;
    border-radius: 6px;
    transition: all 0.2s ease;
}

#workspaces button.active {
    color: #58a6ff;
    background: rgba(88, 166, 255, 0.15);
}

#workspaces button:hover {
    color: #c9d1d9;
    background: rgba(88, 166, 255, 0.1);
}

#workspaces button.urgent {
    color: #f85149;
    background: rgba(248, 81, 73, 0.15);
}

/* Taskbar */
#taskbar button {
    padding: 4px 8px;
    color: #8b949e;
    background: transparent;
    border-radius: 6px;
    transition: all 0.2s ease;
}

#taskbar button.active {
    color: #58a6ff;
    background: rgba(88, 166, 255, 0.15);
    border-bottom: 2px solid #58a6ff;
}

#taskbar button:hover {
    color: #c9d1d9;
    background: rgba(88, 166, 255, 0.1);
}

/* Clock */
#clock {
    color: #c9d1d9;
    font-weight: 600;
    padding: 0 16px;
}

/* System tray */
#tray {
    padding: 0 8px;
}

#tray > .passive {
    color: #8b949e;
}

#tray > .needs-attention {
    color: #f85149;
}

/* Audio */
#pulseaudio {
    color: #c9d1d9;
}

#pulseaudio.muted {
    color: #8b949e;
}

/* Network */
#network {
    color: #c9d1d9;
}

#network.disconnected {
    color: #f85149;
}

/* Bluetooth */
#bluetooth {
    color: #79c0ff;
}

#bluetooth.disabled {
    color: #8b949e;
}

/* Battery */
#battery {
    color: #c9d1d9;
}

#battery.warning {
    color: #d29922;
}

#battery.critical {
    color: #f85149;
    animation: blink 1s infinite;
}

/* Power button */
#custom-power {
    color: #f85149;
    padding: 0 14px;
    font-size: 14px;
}

#custom-power:hover {
    background: rgba(248, 81, 73, 0.15);
}

/* Animations */
@keyframes blink {
    to {
        color: #0d1117;
    }
}
WAYBAR_CSS_EOF

# ==============================================================================
# 11. DUNST CONFIGURATION
# ==============================================================================

echo "==> [LinkSOS] Configuring Dunst notifications..."

cat > /etc/skel/.config/dunst/dunstrc << 'DUNST_EOF'
[global]
    monitor = 0
    follow = mouse
    width = 360
    height = 200
    origin = top-right
    offset = "15x15"
    scale = 0
    notification_limit = 5
    progress_bar = true
    progress_bar_height = 8
    progress_bar_frame_width = 1
    progress_bar_min_width = 150
    progress_bar_max_width = 300
    indicate_hidden = yes
    transparency = 10
    separator_height = 2
    padding = 12
    horizontal_padding = 12
    text_icon_padding = 8
    frame_width = 1
    frame_color = "#30363d"
    separator_color = frame
    sort = yes
    idle_threshold = 120
    font = Noto Sans 11
    line_height = 0
    markup = full
    format = "<b>%s</b>\n%b"
    alignment = left
    vertical_alignment = center
    show_age_threshold = 60
    ellipsize = middle
    ignore_newline = no
    stack_duplicates = true
    hide_duplicate_count = false
    show_indicators = yes
    icon_position = left
    min_icon_size = 32
    max_icon_size = 64
    icon_path = /usr/share/icons/Tela-blue-dark/16/actions:/usr/share/icons/Tela-blue-dark/16/apps:/usr/share/icons/Tela-blue-dark/16/status
    sticky_history = yes
    history_length = 20
    dmenu = /usr/bin/rofi -dmenu -p dunst
    browser = /usr/bin/brave 2>/dev/null || /usr/bin/firefox
    always_run_script = true
    title = Dunst
    class = Dunst
    corner_radius = 12
    ignore_dbusclose = false

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
DUNST_EOF

# ==============================================================================
# 12. ROFI CONFIGURATION
# ==============================================================================

echo "==> [LinkSOS] Configuring Rofi launcher..."

cat > /etc/skel/.config/rofi/config.rasi << 'ROFI_EOF'
configuration {
    modi: "drun,run,window";
    font: "Noto Sans 12";
    show-icons: true;
    icon-theme: "Tela-blue-dark";
    drun-display-format: "{name}";
    disable-history: false;
    sidebar-mode: false;
    matching: "fuzzy";
    sorting-method: "fzf";
    click-to-exit: true;
    display-drun: "  Apps";
    display-run: "  Run";
    display-window: "  Windows";
}

@theme "/dev/null"

* {
    bg: #0d1117ee;
    bg-alt: #161b22ee;
    fg: #c9d1d9;
    fg-alt: #8b949e;
    accent: #58a6ff;
    border: #30363d;
    urgent: #f85149;
    padding: 8px;
    border-radius: 12px;
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
    margin: 0 0 8px 0;
}

prompt {
    color: @accent;
    margin: 0 8px 0 0;
}

entry {
    color: @fg;
    placeholder: "Search...";
    placeholder-color: @fg-alt;
}

listview {
    margin: 0;
    padding: 0;
    border-radius: 8px;
}

element {
    padding: 10px;
    border-radius: 8px;
    spacing: 8px;
}

element selected {
    background-color: rgba(88, 166, 255, 0.15);
    color: @accent;
}

element-icon {
    size: 28px;
    vertical-align: 0.5;
}

element-text {
    vertical-align: 0.5;
    color: inherit;
}

element urgent {
    color: @urgent;
}
ROFI_EOF

# ==============================================================================
# 13. GTK THEME CONFIGURATION
# ==============================================================================

echo "==> [LinkSOS] Configuring GTK theme..."

cat > /etc/skel/.config/gtk-3.0/settings.ini << 'GTK_EOF'
[Settings]
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Tela-blue-dark
gtk-font-name=Noto Sans 11
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=24
gtk-toolbar-style=GTK_TOOLBAR_BOTH
gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images=1
gtk-menu-images=1
gtk-enable-event-sounds=1
gtk-enable-input-feedback-sounds=1
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
gtk-application-prefer-dark-theme=1
GTK_EOF

# ==============================================================================
# 14. SKEL FILES (Default user home directory)
# ==============================================================================

echo "==> [LinkSOS] Setting up default user configuration..."

# Copy Hyprland config to skel
cp /etc/hypr/hyprland.conf /etc/skel/.config/hypr/hyprland.conf

# Copy Waybar config to skel
cp /etc/waybar/config /etc/skel/.config/waybar/config
cp /etc/waybar/style.css /etc/skel/.config/waybar/style.css

# ==============================================================================
# 15. CUSTOM SCRIPTS
# ==============================================================================

echo "==> [LinkSOS] Creating custom utility scripts..."

# First-run wizard
cat > /usr/local/bin/linksos-first-run << 'FIRST_RUN_EOF'
#!/usr/bin/env bash
# LinkSOS First-Run Wizard
# Shows on first boot to help new users set up their system

CONFIG_DIR="$HOME/.config/linksos"
MARKER="$CONFIG_DIR/.first-run-done"

# Skip if already done
if [ -f "$MARKER" ]; then
    exit 0
fi

mkdir -p "$CONFIG_DIR"

# Show welcome dialog
kdialog --title "Welcome to LinkSOS!" --msgbox \
"Welcome to LinkSOS Linux!

A modern, lightweight, gaming-ready desktop experience.

This wizard will help you:
  • Set up your graphics drivers
  • Install gaming tools
  • Configure your desktop

Click OK to continue!" 2>/dev/null || notify-send "Welcome to LinkSOS!" "A modern, lightweight, gaming-ready desktop experience."

# Ask about GPU driver
GPU_CHOICE=$(kdialog --title "Graphics Setup" --combobox \
"Select your graphics card:" \
"auto" "Auto-detect (Recommended)" \
"nvidia" "NVIDIA" \
"amd" "AMD/ATI" \
"intel" "Intel" 2>/dev/null)

if [ "$GPU_CHOICE" = "nvidia" ]; then
    sudo pacman -S --noconfirm --needed nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings 2>/dev/null
    sudo dkms autoinstall 2>/dev/null
elif [ "$GPU_CHOICE" = "amd" ]; then
    sudo pacman -S --noconfirm --needed mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon 2>/dev/null
elif [ "$GPU_CHOICE" = "intel" ]; then
    sudo pacman -S --noconfirm --needed mesa lib32-mesa vulkan-intel lib32-vulkan-intel 2>/dev/null
fi

# Ask about gaming setup
kdialog --title "Gaming Setup" --yesno \
"Do you want to install gaming tools?

This will install:
  • Steam (with Proton)
  • Lutris
  • Wine
  • MangoHud
  • GameMode" 2>/dev/null

if [ $? -eq 0 ]; then
    sudo pacman -S --noconfirm --needed steam lutris wine winetricks mangohud lib32-mangohud gamemode lib32-gamemode 2>/dev/null
fi

# Mark as done
date > "$MARKER"
echo "==> [LinkSOS] First-run setup complete!"
FIRST_RUN_EOF
chmod +x /usr/local/bin/linksos-first-run

# Gaming setup script
cat > /usr/local/bin/linksos-setup-gaming << 'GAMING_EOF'
#!/usr/bin/env bash
# LinkSOS Gaming Setup Script
# Installs and configures all gaming-related packages

set -euo pipefail

echo "==> [LinkSOS] Setting up gaming environment..."

# Detect GPU and install appropriate drivers
if lspci | grep -i nvidia > /dev/null 2>&1; then
    echo "  → NVIDIA GPU detected"
    pacman -S --noconfirm --needed nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings 2>/dev/null || true
    dkms autoinstall 2>/dev/null || true
elif lspci | grep -i amd > /dev/null 2>&1; then
    echo "  → AMD GPU detected"
    pacman -S --noconfirm --needed mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon 2>/dev/null || true
elif lspci | grep -i intel > /dev/null 2>&1; then
    echo "  → Intel GPU detected"
    pacman -S --noconfirm --needed mesa lib32-mesa vulkan-intel lib32-vulkan-intel 2>/dev/null || true
else
    echo "  → No dedicated GPU detected, installing Mesa"
    pacman -S --noconfirm --needed mesa lib32-mesa 2>/dev/null || true
fi

# Install gaming tools
echo "  → Installing gaming tools..."
pacman -S --noconfirm --needed \
    wine wine-mono wine-gecko winetricks \
    steam lutris \
    mangohud lib32-mangohud \
    gamemode lib32-gamemode \
    gamescope protontricks \
    2>/dev/null || true

# Enable gamemode
systemctl enable --now gamemoded 2>/dev/null || true

# Configure Wine prefix
mkdir -p /home/linksos/.wine 2>/dev/null || true

echo "==> [LinkSOS] Gaming setup complete!"
GAMING_EOF
chmod +x /usr/local/bin/linksos-setup-gaming

# App Center script (simple graphical package manager)
cat > /usr/local/bin/linksos-app-center << 'APPCENTER_EOF'
#!/usr/bin/env bash
# LinkSOS App Center
# Simple graphical application manager

ACTION=$(kdialog --title "LinkSOS App Center" --combobox \
"What would you like to do?" \
"install" "Install Applications" \
"update" "Update System" \
"search" "Search Packages" \
"flatpak" "Install Flatpak Apps" 2>/dev/null)

case "$ACTION" in
    install)
        CATEGORY=$(kdialog --title "App Center" --combobox \
        "Select a category:" \
        "gaming" "Gaming" \
        "browser" "Web Browsers" \
        "media" "Media & Entertainment" \
        "productivity" "Productivity" \
        "development" "Development" 2>/dev/null)
        
        case "$CATEGORY" in
            gaming)
                kdialog --title "Install Gaming Apps" --checklist "Select apps to install:" \
                "steam" "Steam" off \
                "lutris" "Lutris" off \
                "wine" "Wine" off \
                "mangohud" "MangoHud" off \
                "gamescope" "Gamescope" off 2>/dev/null | xargs -I {} sudo pacman -S --noconfirm {} 2>/dev/null
                ;;
            browser)
                kdialog --title "Install Browsers" --checklist "Select browsers to install:" \
                "brave-bin" "Brave" off \
                "firefox" "Firefox" off \
                "chromium" "Chromium" off 2>/dev/null | xargs -I {} yay -S --noconfirm {} 2>/dev/null
                ;;
            *)
                kdialog --title "Install Apps" --inputbox "Enter package name:" "" 2>/dev/null | xargs -I {} sudo pacman -S --noconfirm {} 2>/dev/null
                ;;
        esac
        ;;
    update)
        konsole -e bash -c "sudo pacman -Syu && echo 'Update complete!' && read" 2>/dev/null
        ;;
    search)
        PKG=$(kdialog --title "Search Packages" --inputbox "Enter package name:" "" 2>/dev/null)
        if [ -n "$PKG" ]; then
            konsole -e bash -c "pacman -Ss $PKG && echo '' && read -p 'Press Enter to close...'" 2>/dev/null
        fi
        ;;
    flatpak)
        kdialog --title "Flatpak" --msgbox "Opening Flathub in your browser..." 2>/dev/null
        xdg-open "https://flathub.org" 2>/dev/null
        ;;
esac
APPCENTER_EOF
chmod +x /usr/local/bin/linksos-app-center

# ==============================================================================
# 16. SYSTEMD SERVICES
# ==============================================================================

echo "==> [LinkSOS] Creating systemd services..."

# First-run service
cat > /etc/systemd/system/linksos-first-run.service << 'SERVICE_EOF'
[Unit]
Description=LinkSOS First-Run Wizard
After=sddm.service
Wants=sddm.service

[Service]
Type=oneshot
User=linksos
Environment=DISPLAY=:0
Environment=WAYLAND_DISPLAY=wayland-1
ExecStart=/usr/local/bin/linksos-first-run
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SERVICE_EOF

# Gaming setup service
cat > /etc/systemd/system/linksos-gaming-setup.service << 'SERVICE_EOF'
[Unit]
Description=LinkSOS Gaming Environment Setup
After=NetworkManager.service
Wants=NetworkManager.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/linksos-setup-gaming
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SERVICE_EOF

# ==============================================================================
# 17. SDDM THEME
# ==============================================================================

echo "==> [LinkSOS] Creating SDDM theme..."

cat > /usr/share/sddm/themes/linksos/metadata.desktop << 'SDDM_THEME_EOF'
[SddmGreeterTheme]
Name=LinkSOS
Description=LinkSOS SDDM Login Theme
Version=1.0
Screenshot=preview.png
MainScript=Main.qml
ConfigFile=theme.conf
TranslationsDirectory=translations
Theme-Id=linksos
Theme-API=2
SDDM_THEME_EOF

cat > /usr/share/sddm/themes/linksos/theme.conf << 'SDDM_CONF_EOF'
[General]
background=
type=color
color=#0d1117
font=Noto Sans
fontSize=12
foregroundColor=#c9d1d9
backgroundHorizontalAlignment=center
backgroundVerticalAlignment=center
SDDM_CONF_EOF

cat > /usr/share/sddm/themes/linksos/Main.qml << 'SDDM_QML_EOF'
import QtQuick 2.15
import QtQuick.Controls 2.15
import SddmComponents 2.0

Rectangle {
    id: root
    color: "#0d1117"
    
    Rectangle {
        anchors.fill: parent
        color: "#0d1117"
        
        // Centered login area
        Rectangle {
            id: loginBox
            width: 400
            height: 350
            radius: 16
            color: "#161b22"
            border.color: "#30363d"
            border.width: 1
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
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    background: Rectangle {
                        color: "#0d1117"
                        radius: 8
                        border.color: "#30363d"
                    }
                    onTextChanged: sddm.login(username.text, password.text)
                }
                
                TextField {
                    id: password
                    width: 300
                    height: 44
                    placeholderText: "Password"
                    echoMode: TextInput.Password
                    color: "#c9d1d9"
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    background: Rectangle {
                        color: "#0d1117"
                        radius: 8
                        border.color: "#30363d"
                    }
                    onTextChanged: sddm.login(username.text, password.text)
                    Keys.onReturnPressed: sddm.login(username.text, password.text)
                }
                
                Button {
                    id: loginButton
                    width: 300
                    height: 44
                    anchors.horizontalCenter: parent.horizontalCenter
                    
                    background: Rectangle {
                        color: loginButton.pressed ? "#1f6feb" : "#58a6ff"
                        radius: 8
                    }
                    
                    contentItem: Text {
                        text: "Sign In"
                        color: "#ffffff"
                        font.pixelSize: 14
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: sddm.login(username.text, password.text)
                }
            }
        }
        
        // Bottom bar
        Row {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 20
            spacing: 20
            
            Button {
                id: shutdown
                background: Rectangle {
                    color: shutdown.pressed ? "#30363d" : "transparent"
                    radius: 8
                    width: 80
                    height: 36
                }
                contentItem: Text {
                    text: "⏻ Shutdown"
                    color: "#8b949e"
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: sddm.powerOff()
            }
            
            Button {
                id: reboot
                background: Rectangle {
                    color: reboot.pressed ? "#30363d" : "transparent"
                    radius: 8
                    width: 80
                    height: 36
                }
                contentItem: Text {
                    text: "↻ Reboot"
                    color: "#8b949e"
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: sddm.reboot()
            }
        }
    }
}
SDDM_QML_EOF

# ==============================================================================
# 18. WALLPAPERS
# ==============================================================================

echo "==> [LinkSOS] Setting up wallpapers..."

mkdir -p /usr/share/wallpapers/linksos

# Create a simple gradient wallpaper using ImageMagick
if command -v convert &> /dev/null; then
    convert -size 1920x1080 \
        gradient:'#0d1117'-'#1a1f2e' \
        /usr/share/wallpapers/linksos/default.png 2>/dev/null || \
    convert -size 1920x1080 \
        xc:'#0d1117' \
        /usr/share/wallpapers/linksos/default.png 2>/dev/null || true
fi

# Fallback if ImageMagick fails
if [ ! -f /usr/share/wallpapers/linksos/default.png ]; then
    # Create a minimal PNG file (1x1 pixel dark blue)
    printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\x0cIDATx\x9cc\xf8\x0f\x00\x00\x01\x01\x00\x05\x18\xd8N\x00\x00\x00\x00IEND\xaeB`\x82' > /usr/share/wallpapers/linksos/default.png
fi

# ==============================================================================
# 19. LOCALE AND TIMEZONE
# ==============================================================================

echo "==> [LinkSOS] Configuring locale..."

# Enable common locales
sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/#en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/#zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/#ja_JP.UTF-8 UTF-8/ja_JP.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/#ko_KR.UTF-8 UTF-8/ko_KR.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/#de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/#fr_FR.UTF-8 UTF-8/fr_FR.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/#es_ES.UTF-8 UTF-8/es_ES.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/#pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/' /etc/locale.gen
locale-gen

echo "LANG=en_US.UTF-8" > /etc/locale.conf

# ==============================================================================
# 20. FINAL CLEANUP
# ==============================================================================

echo "==> [LinkSOS] Performing final cleanup..."

# Remove build user if exists
userdel -r archiso 2>/dev/null || true

# Clean pacman cache
yes | pacman -Scc 2>/dev/null || true

# Remove unused packages
pacman -Rns --noconfirm $(pacman -Qdtq) 2>/dev/null || true

# Set permissions
chmod 0750 /root
chmod 0400 /etc/shadow
chmod 0400 /etc/gshadow

# Create default directories for user
mkdir -p /etc/skel/Desktop
mkdir -p /etc/skel/Documents
mkdir -p /etc/skel/Downloads
mkdir -p /etc/skel/Music
mkdir -p /etc/skel/Pictures
mkdir -p /etc/skel/Videos
mkdir -p /etc/skel/Games

# Create desktop shortcuts
cat > /etc/skel/Desktop/calamares.desktop << 'DESKTOP_EOF'
[Desktop Entry]
Type=Application
Name=Install LinkSOS
GenericName=System Installer
Exec=/usr/bin/calamares
Icon=calamares
Terminal=false
Categories=System;
DESKTOP_EOF
chmod +x /etc/skel/Desktop/calamares.desktop

cat > /etc/skel/Desktop/app-center.desktop << 'DESKTOP_EOF'
[Desktop Entry]
Type=Application
Name=App Center
GenericName=Application Manager
Exec=/usr/local/bin/linksos-app-center
Icon=system-software-install
Terminal=false
Categories=System;
DESKTOP_EOF
chmod +x /etc/skel/Desktop/app-center.desktop

echo "==> [LinkSOS] airootfs customization complete!"
