#!/usr/bin/env bash
# ==============================================================================
# LinkSOS - Docker Build Script
# For building the ISO inside a Docker container (non-Arch Linux hosts)
# ==============================================================================

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║             LinkSOS Docker Build Script                     ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is not installed!"
    echo "Please install Docker first: https://docs.docker.com/get-docker/"
    exit 1
fi

echo -e "${GREEN}==> Building ISO inside Arch Linux Docker container...${NC}"
echo -e "${YELLOW}    This may take 2-4 hours depending on your machine.${NC}"
echo ""

# Run the build inside an Arch Linux container
docker run --rm \
    --privileged \
    -v "${PROJECT_DIR}:/workspace" \
    -v "/tmp/linksos-docker-work:/tmp/archiso-work" \
    archlinux:latest \
    bash -c "
        pacman -Syu --noconfirm && \
        pacman -S --noconfirm --needed archiso base-devel squashfs-tools git curl wget reflector imagemagick && \
        reflector --country 'US,DE,FR,GB,NL,JP' --latest 20 --sort rate --save /etc/pacman.d/mirrorlist && \
        cd /workspace && \
        chmod +x scripts/build-iso.sh && \
        bash scripts/build-iso.sh
    "

echo -e "${GREEN}==> Docker build complete!${NC}"
echo -e "${YELLOW}    Check the 'out/' directory for the ISO file.${NC}"
