#!/usr/bin/env bash
# ==============================================================================
# LinkSOS - Local Build Script
# For building the ISO locally (outside of CI/CD)
# ==============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                  LinkSOS ISO Build Script                    ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
PROFILE_DIR="${PROJECT_DIR}/archiso"
WORK_DIR="/tmp/linksos-build-work"
OUT_DIR="${PROJECT_DIR}/out"

# Check if running on Arch Linux
if [ ! -f "/etc/arch-release" ]; then
    echo -e "${RED}ERROR: This script requires Arch Linux!${NC}"
    echo -e "${YELLOW}You can run it inside an Arch Linux Docker container:${NC}"
    echo "  docker run --privileged -it -v ${PROJECT_DIR}:/workspace archlinux:latest bash"
    echo "  cd /workspace && ./scripts/build-iso.sh"
    exit 1
fi

# Check if archiso is installed
if ! command -v mkarchiso &> /dev/null; then
    echo -e "${YELLOW}==> Installing archiso...${NC}"
    pacman -S --noconfirm --needed archiso base-devel squashfs-tools git curl wget reflector imagemagick
fi

# Step 1: Update mirrors
echo -e "${GREEN}==> [1/5] Updating mirror list...${NC}"
reflector --country "US,DE,FR,GB,NL,JP" --latest 20 --sort rate --save /etc/pacman.d/mirrorlist

# Step 2: Verify profile
echo -e "${GREEN}==> [2/5] Verifying archiso profile...${NC}"
if [ ! -f "${PROFILE_DIR}/profiledef.sh" ]; then
    echo -e "${RED}ERROR: profiledef.sh not found!${NC}"
    exit 1
fi

if [ ! -f "${PROFILE_DIR}/packages.x86_64" ]; then
    echo -e "${RED}ERROR: packages.x86_64 not found!${NC}"
    exit 1
fi

chmod +x "${PROFILE_DIR}/customize_airootfs.sh" 2>/dev/null || true

echo -e "${GREEN}    Profile: ${PROFILE_DIR}${NC}"
echo -e "${GREEN}    Output:  ${OUT_DIR}${NC}"

# Step 3: Clean previous builds
echo -e "${GREEN}==> [3/5] Cleaning previous build artifacts...${NC}"
rm -rf "${WORK_DIR}" 2>/dev/null || true
rm -rf "${OUT_DIR}" 2>/dev/null || true
mkdir -p "${OUT_DIR}"

# Step 4: Build ISO
echo -e "${GREEN}==> [4/5] Building ISO (this may take 2-4 hours)...${NC}"
echo -e "${YELLOW}    Starting mkarchiso build...${NC}"

START_TIME=$(date +%s)

mkarchiso -v -w "${WORK_DIR}" -o "${OUT_DIR}" "${PROFILE_DIR}"

END_TIME=$(date +%s)
BUILD_TIME=$((END_TIME - START_TIME))
BUILD_MINUTES=$((BUILD_TIME / 60))

echo -e "${GREEN}    Build completed in ${BUILD_MINUTES} minutes!${NC}"

# Step 5: Verify and report
echo -e "${GREEN}==> [5/5] Verifying ISO output...${NC}"

ISO_FILE=$(find "${OUT_DIR}" -name "*.iso" -type f | head -1)

if [ -z "${ISO_FILE}" ]; then
    echo -e "${RED}ERROR: No ISO file found!${NC}"
    ls -la "${OUT_DIR}/"
    exit 1
fi

ISO_SIZE=$(du -h "${ISO_FILE}" | cut -f1)
SHA256=$(sha256sum "${ISO_FILE}" | cut -d' ' -f1)

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                  Build Successful!                           ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}  ISO File:     ${ISO_FILE}${NC}"
echo -e "${GREEN}  ISO Size:     ${ISO_SIZE}${NC}"
echo -e "${GREEN}  SHA256:       ${SHA256}${NC}"
echo -e "${GREEN}  Build Time:   ${BUILD_MINUTES} minutes${NC}"
echo ""
echo -e "${YELLOW}  To flash to USB:${NC}"
echo "    sudo dd if=${ISO_FILE} of=/dev/sdX bs=4M status=progress && sync"
echo ""
echo -e "${YELLOW}  Or use Ventoy/Rufus for easier flashing.${NC}"
