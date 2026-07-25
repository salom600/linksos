#!/usr/bin/env bash
# shellcheck disable=SC2034

# LinkSOS Arch ISO Profile Definition
# Lightweight gaming-focused Linux distribution for ex-Windows users

iso_name="linksos"
iso_label="LINKSOS_$(date +%Y%m)"
iso_publisher="LinkSOS Project <https://github.com/salom600/linksos>"
iso_application="LinkSOS Linux - Modern Gaming Desktop"
iso_version="$(date +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux.mbr' 'bios.syslinux.partition' 'uefi-x64.grub.esp' 'uefi-x64.grub.legacy')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '3')
file_permissions=(
  ["/etc/shadow"]="0:0:0400"
  ["/etc/gshadow"]="0:0:0400"
  ["/root"]="0:0:0750"
  ["/etc/sudoers"]="0:0:0440"
  ["/etc/sudoers.d"]="0:0:0750"
  ["/usr/local/bin/linksos-first-run"]="0:0:0755"
  ["/usr/local/bin/linksos-setup-gaming"]="0:0:0755"
  ["/usr/local/bin/linksos-app-center"]="0:0:0755"
)
