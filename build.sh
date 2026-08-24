#!/bin/bash
set -euo pipefail

# ==============================================================================
# RED OS ISO to Docker Image Builder (Multi-Version & Multi-Preset)
# ==============================================================================
# Usage:
#   ./build.sh [OPTIONS] [iso_file_or_url ...]
#
# Options:
#   -p, --preset <minimal|server|workstation>  Preset to build (default: minimal)
#   --prefix <image_repo>                     Image repository name (default: runalsh/redos-patch)
#   --force                                   Skip registry check and force rebuild
#   -h, --help                                Show this help message
# ==============================================================================

IMAGE_NAME="${IMAGE_NAME:-runalsh/redos-patch}"
RELEASES_FILE="${RELEASES_FILE:-releases.txt}"
PRESET_CHOICE="minimal"
SKIP_EXISTS_CHECK="${SKIP_EXISTS_CHECK:-false}"
PUSH_TO_DOCKERHUB="${PUSH_TO_DOCKERHUB:-false}"
PUSH_TO_GHCR="${PUSH_TO_GHCR:-false}"
TEST_VERSION="${TEST_VERSION:-true}"
CLI_ISOS=()

# Terminal colors
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_BLUE="\033[1;34m"
C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"
C_RED="\033[1;31m"
C_CYAN="\033[1;36m"
C_MAGENTA="\033[1;35m"
C_GRAY="\033[0;90m"

# Sudo helper for commands requiring root
s() {
  if [ "$(id -u)" -ne 0 ] && command -v sudo &>/dev/null; then
    sudo "$@"
  else
    "$@"
  fi
}

ts() { date "+%Y-%m-%d %H:%M:%S"; }
log_info() { echo -e "${C_CYAN}[$(ts)]${C_RESET} ${C_BLUE}[INFO]${C_RESET} $1"; }
log_step() { echo -e "\n${C_CYAN}[$(ts)]${C_RESET} ${C_MAGENTA}${C_BOLD}===> $1${C_RESET}"; }
log_exec() { echo -e "${C_CYAN}[$(ts)]${C_RESET} ${C_GRAY}[EXEC] + $1${C_RESET}"; }
log_success() { echo -e "${C_CYAN}[$(ts)]${C_RESET} ${C_GREEN}[SUCCESS]${C_RESET} $1"; }
log_warn() { echo -e "${C_CYAN}[$(ts)]${C_RESET} ${C_YELLOW}[WARNING]${C_RESET} $1"; }
log_error() { echo -e "${C_CYAN}[$(ts)]${C_RESET} ${C_RED}[ERROR]${C_RESET} $1"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--preset)
      PRESET_CHOICE="$2"
      shift 2
      ;;
    --prefix)
      IMAGE_NAME="$2"
      shift 2
      ;;
    --force)
      SKIP_EXISTS_CHECK="true"
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS] [iso_file_or_url ...]"
      echo "  -p, --preset <name>   Preset to build (minimal|server|workstation, default: minimal)"
      echo "  --prefix <repo>       Image repository name (default: runalsh/redos-patch)"
      echo "  --force               Force rebuild even if tag exists in remote registry"
      exit 0
      ;;
    *)
      CLI_ISOS+=("$1")
      shift
      ;;
  esac
done

# Universal preset resolution for RedOS 8 and RedOS 7.3
get_group_for_version() {
  local major="$1"
  local preset="$2"
  if [ "$major" = "8" ]; then
    case "$preset" in
      minimal|server-minimal*) echo "server-minimal-environment" ;;
      server|server-gui*)      echo "server-product-environment" ;;
      workstation*)            echo "workstation-product-environment" ;;
      *)                       echo "$preset" ;;
    esac
  else # RedOS 7
    case "$preset" in
      minimal|server-minimal*) echo "server-minimal" ;;
      server|server-gui*)      echo "graphical-server-environment" ;;
      workstation*)            echo "desktop-environment" ;;
      *)                       echo "$preset" ;;
    esac
  fi
}

declare -a TARGETS=()

if [ ${#CLI_ISOS[@]} -gt 0 ]; then
  for item in "${CLI_ISOS[@]}"; do
    if [[ "$item" =~ ^https?:// ]]; then
      tag=$(basename "$item" .iso | sed -E 's/redos-(MUROM-)?//;s/-Everything.*//')
      TARGETS+=("$tag|$item")
    elif [ -f "$item" ]; then
      tag=$(basename "$item" .iso | sed -E 's/redos-(MUROM-)?//;s/-Everything.*//')
      TARGETS+=("$tag|$item")
    else
      log_warn "File '$item' not found, skipping."
    fi
  done
elif [ -f "$RELEASES_FILE" ]; then
  while read -r tag url || [ -n "$tag" ]; do
    [[ -z "$tag" || "$tag" =~ ^# ]] && continue
    TARGETS+=("$tag|$url")
  done < "$RELEASES_FILE"
else
  log_error "Neither $RELEASES_FILE nor CLI ISO arguments were provided!"
  exit 1
fi

echo -e "${C_BOLD}==============================================================================${C_RESET}"
echo -e "${C_GREEN}${C_BOLD}RED OS ISO Docker Multi-Release Builder${C_RESET}"
echo -e "Repository:            ${C_YELLOW}${IMAGE_NAME}${C_RESET}"
echo -e "Preset:                ${C_YELLOW}${PRESET_CHOICE}${C_RESET}"
echo -e "Releases in queue:     ${#TARGETS[@]}"
echo -e "Push to Docker Hub:    ${PUSH_TO_DOCKERHUB}"
echo -e "Push to GHCR:          ${PUSH_TO_GHCR}"
echo -e "${C_BOLD}==============================================================================${C_RESET}"

global_cleanup() {
  log_info "Running pre-build cleanup of any leftover mounts and temporary files..."
  for m in $(mount 2>/dev/null | grep -E '/tmp/iso_mnt_' | awk '{print $3}' || true); do
    s umount "$m" 2>/dev/null || true
  done
  s rm -rf /tmp/iso_mnt_* /tmp/redos_rootfs_* /tmp/download_*.iso 2>/dev/null || true
}
global_cleanup

SUCCESS_TAGS=()

for target in "${TARGETS[@]}"; do
  tag="${target%%|*}"
  source="${target##*|}"

  log_step "Processing release: tag='${tag}', source='${source}'"

  MAJOR_VER=$(echo "$tag" | grep -oE '^[0-9]+' || echo "8")
  
  FULL_IMAGE_TAG="${IMAGE_NAME}:${tag}-${PRESET_CHOICE}"
  GHCR_IMAGE_NAME="ghcr.io/$(echo "${IMAGE_NAME}" | tr '[:upper:]' '[:lower:]')"
  FULL_GHCR_TAG="${GHCR_IMAGE_NAME}:${tag}-${PRESET_CHOICE}"

  # Check if image already exists in remote registries
  if [ "$SKIP_EXISTS_CHECK" != "true" ]; then
    dh_exists=false
    ghcr_exists=false
    if [ "$PUSH_TO_DOCKERHUB" = "true" ]; then
      if docker manifest inspect "${FULL_IMAGE_TAG}" &>/dev/null || curl -sfSL "https://hub.docker.com/v2/repositories/${IMAGE_NAME}/tags/${tag}/" &>/dev/null; then
        dh_exists=true
      fi
    else
      dh_exists=true
    fi
    if [ "$PUSH_TO_GHCR" = "true" ]; then
      if docker manifest inspect "${FULL_GHCR_TAG}" &>/dev/null; then
        ghcr_exists=true
      fi
    else
      ghcr_exists=true
    fi
    if [ "$dh_exists" = "true" ] && [ "$ghcr_exists" = "true" ] && { [ "$PUSH_TO_DOCKERHUB" = "true" ] || [ "$PUSH_TO_GHCR" = "true" ]; }; then
      log_success "Tag ${FULL_IMAGE_TAG} already exists on all enabled registries. Skipping build."
      continue
    fi
  fi

  RAND_ID=$(head /dev/urandom | tr -dc a-z0-9 | head -c 8 ; echo '')
  LOCAL_ISO=""
  MNT_DIR="/tmp/iso_mnt_${RAND_ID}"
  ROOTFS_DIR="/tmp/redos_rootfs_${RAND_ID}"

  cleanup_run() {
    log_info "Cleaning up temporary mount points and rootfs directory..."
    s umount "$MNT_DIR" 2>/dev/null || true
    s rm -rf "$MNT_DIR" "$ROOTFS_DIR"
    if [[ "$source" =~ ^https?:// ]] && [ -f "${LOCAL_ISO:-}" ]; then
      log_info "Removing downloaded temporary ISO: $LOCAL_ISO"
      rm -f "$LOCAL_ISO"
    fi
    if [ "${CLEANUP_DOCKER_IMAGES:-true}" = "true" ]; then
      log_info "Pruning local Docker images for this tag to free disk space..."
      docker rmi -f "${FULL_IMAGE_TAG}" "${FULL_GHCR_TAG}" 2>/dev/null || true
      for extra_tag in "${ALL_EXTRA_TAGS[@]:-}"; do
        docker rmi -f "${IMAGE_NAME}:${extra_tag}-${PRESET_CHOICE}" "${GHCR_IMAGE_NAME}:${extra_tag}-${PRESET_CHOICE}" 2>/dev/null || true
      done
    fi
  }
  trap cleanup_run EXIT INT TERM HUP

  log_exec "mkdir -p $MNT_DIR $ROOTFS_DIR"
  mkdir -p "$MNT_DIR" "$ROOTFS_DIR"

  if [[ "$source" =~ ^https?:// ]]; then
    fname=$(basename "$source")
    if [ -f "/$fname" ]; then
      LOCAL_ISO="/$fname"
      log_info "Found local cached ISO: $LOCAL_ISO (download skipped)"
    elif [ -f "./$fname" ]; then
      LOCAL_ISO="./$fname"
      log_info "Found local cached ISO: $LOCAL_ISO (download skipped)"
    else
      LOCAL_ISO="/tmp/download_${RAND_ID}.iso"
      log_info "Downloading ISO from ${source} (silent in CI)..."
      log_exec "curl -fLC - -sS --show-error -o $LOCAL_ISO $source"
      curl -fLC - -sS --show-error -o "$LOCAL_ISO" "$source"
      ISO_SIZE=$(du -h "$LOCAL_ISO" | awk '{print $1}')
      log_success "Download complete. File size: ${ISO_SIZE}"
    fi
  else
    LOCAL_ISO="$source"
  fi

  log_info "Preparing ISO contents in $MNT_DIR..."
  if command -v 7z &>/dev/null; then
    log_exec "7z x -y -bso0 -bsp0 -o$MNT_DIR $LOCAL_ISO"
    7z x -y -bso0 -bsp0 -o"$MNT_DIR" "$LOCAL_ISO"
  elif command -v bsdtar &>/dev/null; then
    log_exec "bsdtar -xf $LOCAL_ISO -C $MNT_DIR"
    bsdtar -xf "$LOCAL_ISO" -C "$MNT_DIR"
  else
    log_exec "sudo mount -o loop,ro $LOCAL_ISO $MNT_DIR || mount -o loop,ro $LOCAL_ISO $MNT_DIR"
    sudo mount -o loop,ro "$LOCAL_ISO" "$MNT_DIR" 2>/dev/null || mount -o loop,ro "$LOCAL_ISO" "$MNT_DIR"
  fi

  DETECTED_RELEASE=""
  if [ -f "$MNT_DIR/.treeinfo" ]; then
    DETECTED_RELEASE=$(grep -E '^[[:space:]]*version[[:space:]]*=' "$MNT_DIR/.treeinfo" | head -n1 | awk -F'=' '{print $2}' | tr -d ' "\r\n')
  fi
  if [ -z "$DETECTED_RELEASE" ]; then
    DETECTED_RELEASE="$MAJOR_VER"
  fi

  ACTUAL_MAJOR=$(echo "$DETECTED_RELEASE" | grep -oE '[0-9]+' | head -n1 || echo "$MAJOR_VER")
  TARGET_GROUP=$(get_group_for_version "$ACTUAL_MAJOR" "$PRESET_CHOICE")

  log_info "Detected release: ${DETECTED_RELEASE} (Major: ${ACTUAL_MAJOR}), Selected group: ${TARGET_GROUP}"

  log_step "Installing package group '${TARGET_GROUP}' via dnf --installroot"
  log_exec "dnf --installroot=$ROOTFS_DIR --nogpgcheck --disablerepo=* --repofrompath=iso,$MNT_DIR --releasever=${ACTUAL_MAJOR} group install ${TARGET_GROUP}"
  if ! s dnf --installroot="$ROOTFS_DIR" \
      --nogpgcheck \
      --disablerepo='*' \
      --repofrompath=iso,"$MNT_DIR" \
      --setopt=install_weak_deps=False \
      --setopt=tsflags=nodocs \
      --releasever="${ACTUAL_MAJOR}" \
      -y group install "${TARGET_GROUP}"; then
      
      log_warn "Group install '${TARGET_GROUP}' failed, falling back to @core @standard..."
      log_exec "dnf --installroot=$ROOTFS_DIR ... install @core @standard redos-release"
      s dnf --installroot="$ROOTFS_DIR" \
          --nogpgcheck \
          --disablerepo='*' \
          --repofrompath=iso,"$MNT_DIR" \
          --setopt=install_weak_deps=False \
          --setopt=tsflags=nodocs \
          --releasever="${ACTUAL_MAJOR}" \
          -y install @core @standard redos-release
  fi

  log_step "Deep optimization of rootfs for Docker container"
  log_exec "Removing unneeded kernel, firmware, and desktop packages from RPM DB..."
  s rpm --root "$ROOTFS_DIR" -e --nodeps \
    kernel-lt kernel \
    linux-firmware atheros-firmware amd-gpu-firmware nvidia-gpu-firmware \
    mt7xxx-firmware intel-gpu-firmware brcmfmac-firmware realtek-firmware \
    intel-audio-firmware tiwilink-firmware libertas-firmware \
    guile22 fwupd systemd-boot-unsigned binutils binutils-gold \
    grub2-tools grub2-redos-theme grub2-common grubby 2>/dev/null || true

  log_exec "Purging /lib/modules, /lib/firmware, /usr/lib64/dri, /boot..."
  s rm -rf "$ROOTFS_DIR"/lib/modules/* "$ROOTFS_DIR"/usr/lib/modules/* "$ROOTFS_DIR"/boot/* 2>/dev/null || true
  s rm -rf "$ROOTFS_DIR"/lib/firmware/* "$ROOTFS_DIR"/usr/lib/firmware/* "$ROOTFS_DIR"/usr/lib64/dri/* "$ROOTFS_DIR"/usr/lib/dri/* 2>/dev/null || true

  log_exec "Purging documentation, man pages, caches, licenses, and temporary files..."
  s rm -rf "$ROOTFS_DIR"/var/cache/dnf/* "$ROOTFS_DIR"/var/cache/yum/* "$ROOTFS_DIR"/var/log/* "$ROOTFS_DIR"/tmp/* 2>/dev/null || true
  s rm -rf "$ROOTFS_DIR"/usr/share/doc/* "$ROOTFS_DIR"/usr/share/man/* "$ROOTFS_DIR"/usr/share/info/* "$ROOTFS_DIR"/usr/share/licenses/* 2>/dev/null || true

  log_exec "Stripping non-English locales (preserving en* and POSIX)..."
  if [ -d "$ROOTFS_DIR/usr/share/locale" ]; then
    find "$ROOTFS_DIR/usr/share/locale" -mindepth 1 -maxdepth 1 ! -name 'en*' ! -name 'POSIX' -exec rm -rf {} + 2>/dev/null || true
  fi

  log_exec "Purging Python test suites, cracklib wordlists, and hwdb.bin..."
  s rm -rf "$ROOTFS_DIR"/usr/lib64/python3*/test "$ROOTFS_DIR"/usr/lib/python3*/test "$ROOTFS_DIR"/usr/lib64/guile 2>/dev/null || true
  s rm -f "$ROOTFS_DIR"/etc/udev/hwdb.bin "$ROOTFS_DIR"/usr/share/cracklib/cracklib-small.pwd 2>/dev/null || true

  log_info "Configuring systemd units for container compatibility..."
  s rm -f "$ROOTFS_DIR"/lib/systemd/system/multi-user.target.wants/* 2>/dev/null || true
  s rm -f "$ROOTFS_DIR"/etc/systemd/system/*.wants/* 2>/dev/null || true
  s rm -f "$ROOTFS_DIR"/lib/systemd/system/local-fs.target.wants/* 2>/dev/null || true
  s rm -f "$ROOTFS_DIR"/lib/systemd/system/sockets.target.wants/*udev* 2>/dev/null || true
  s rm -f "$ROOTFS_DIR"/lib/systemd/system/sockets.target.wants/*initctl* 2>/dev/null || true
  s rm -f "$ROOTFS_DIR"/lib/systemd/system/basic.target.wants/* 2>/dev/null || true
  s rm -f "$ROOTFS_DIR"/lib/systemd/system/anaconda.target.wants/* 2>/dev/null || true
  if [[ -d "$ROOTFS_DIR/lib/systemd/system/sysinit.target.wants" ]]; then
    (cd "$ROOTFS_DIR/lib/systemd/system/sysinit.target.wants" && for f in *; do [[ "$f" != "systemd-tmpfiles-setup.service" ]] && rm -f "$f"; done) 2>/dev/null || true
  fi

  # Optional: Uncomment if DinD (Docker-in-Docker) preconfiguration is needed directly in base image
  # log_info "Configuring containerd and Docker for DinD (Docker-in-Docker) support..."
  # s mkdir -p "$ROOTFS_DIR"/etc/systemd/system/containerd.service.d "$ROOTFS_DIR"/etc/docker
  # cat << 'EOF_DIND' > "$ROOTFS_DIR"/etc/systemd/system/containerd.service.d/override.conf
  # [Service]
  # ExecStartPre=
  # EOF_DIND
  # cat << 'EOF_DIND_DAEMON' > "$ROOTFS_DIR"/etc/docker/daemon.json
  # {
  #   "storage-driver": "vfs",
  #   "iptables": false
  # }
  # EOF_DIND_DAEMON

  log_info "Migrating RPM database to SQLite backend and importing distribution GPG keys..."
  log_exec "rpm --root $ROOTFS_DIR --rebuilddb && rpm --import GPG-KEYS"
  s rm -rf "$ROOTFS_DIR"/usr/lib/sysimage/rpm "$ROOTFS_DIR"/var/lib/rpm/.migratedb "$ROOTFS_DIR"/var/lib/rpmrebuilddb.* "$ROOTFS_DIR"/usr/lib/sysimage/rpmrebuilddb.* 2>/dev/null || true
  s mkdir -p "$ROOTFS_DIR"/usr/lib/sysimage/rpm
  s mv "$ROOTFS_DIR"/var/lib/rpm/* "$ROOTFS_DIR"/usr/lib/sysimage/rpm/ 2>/dev/null || true
  s rm -rf "$ROOTFS_DIR"/var/lib/rpm
  s ln -sf /usr/lib/sysimage/rpm "$ROOTFS_DIR"/var/lib/rpm
  s rpm --root "$ROOTFS_DIR" --rebuilddb 2>/dev/null || true
  s rpm --root "$ROOTFS_DIR" --import "$ROOTFS_DIR"/etc/pki/rpm-gpg/RPM-GPG-KEY* 2>/dev/null || true

  log_step "Importing rootfs into Docker -> ${FULL_IMAGE_TAG}"
  log_exec "tar -C $ROOTFS_DIR -c . | docker import -c 'ENV container=docker' -c 'ENV LANG=en_US.UTF-8' -c 'STOPSIGNAL SIGRTMIN+3' -c 'CMD [\"/sbin/init\"]' - ${FULL_IMAGE_TAG}"
  s tar -C "$ROOTFS_DIR" -c . | docker import \
    -c "ENV container=docker" \
    -c "ENV LANG=en_US.UTF-8" \
    -c "ENV LC_ALL=en_US.UTF-8" \
    -c "STOPSIGNAL SIGRTMIN+3" \
    -c 'CMD ["/sbin/init"]' \
    - "${FULL_IMAGE_TAG}"

  # Determine exact version dynamically from inside the installed rootfs
  INTERNAL_VERSION=""
  if [ -f "$ROOTFS_DIR/etc/os-release" ]; then
    INTERNAL_VERSION=$(grep -E '^VERSION_ID=' "$ROOTFS_DIR/etc/os-release" | head -n1 | cut -d= -f2 | tr -d ' "
')
  fi
  if [ -z "$INTERNAL_VERSION" ]; then
    INTERNAL_VERSION=$(s rpm --root "$ROOTFS_DIR" -q --queryformat '%{VERSION}' redos-release 2>/dev/null || true)
  fi
  if [ -z "$INTERNAL_VERSION" ]; then
    INTERNAL_VERSION="$DETECTED_RELEASE"
  fi

  # Extract semantic components from the internal system version
  if [[ "$INTERNAL_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
    PATCH_VER="$INTERNAL_VERSION"
    MINOR_VER=$(echo "$INTERNAL_VERSION" | cut -d. -f1,2)
  elif [[ "$INTERNAL_VERSION" =~ ^[0-9]+\.[0-9]+ ]]; then
    PATCH_VER="$INTERNAL_VERSION"
    MINOR_VER="$INTERNAL_VERSION"
  else
    PATCH_VER="${ACTUAL_MAJOR}.0.0"
    MINOR_VER="${ACTUAL_MAJOR}.0"
  fi
  MAJOR_VER="$ACTUAL_MAJOR"

  log_info "Extracted release versions:"
  log_info "  -> Full Tag:  $tag"
  log_info "  -> Patch Ver: $PATCH_VER"
  log_info "  -> Minor Ver: $MINOR_VER"
  log_info "  -> Major Ver: $MAJOR_VER"

  declare -a ALL_EXTRA_TAGS=()
  [ -n "$PATCH_VER" ] && [ "$PATCH_VER" != "$tag" ] && ALL_EXTRA_TAGS+=("$PATCH_VER")
  [ -n "$MINOR_VER" ] && [ "$MINOR_VER" != "$PATCH_VER" ] && ALL_EXTRA_TAGS+=("$MINOR_VER")
  [ -n "$MAJOR_VER" ] && ALL_EXTRA_TAGS+=("$MAJOR_VER")

  for extra_tag in "${ALL_EXTRA_TAGS[@]}"; do
    ext_t="${extra_tag}-${PRESET_CHOICE}"
    
    log_exec "docker tag ${FULL_IMAGE_TAG} ${IMAGE_NAME}:${ext_t}"
    docker tag "${FULL_IMAGE_TAG}" "${IMAGE_NAME}:${ext_t}"
    log_exec "docker tag ${FULL_IMAGE_TAG} ${GHCR_IMAGE_NAME}:${ext_t}"
    docker tag "${FULL_IMAGE_TAG}" "${GHCR_IMAGE_NAME}:${ext_t}"
  done
  docker tag "${FULL_IMAGE_TAG}" "${FULL_GHCR_TAG}"

  if [ "$TEST_VERSION" = "true" ]; then
    log_step "Validating generated Docker image"
    log_exec "docker run --rm ${FULL_IMAGE_TAG} cat /etc/redos-release"
    TEST_REL=$(docker run --rm "${FULL_IMAGE_TAG}" cat /etc/redos-release 2>&1)
    echo -e "${C_CYAN}------------------------------------------------------------${C_RESET}"
    echo -e "${C_BOLD}/etc/redos-release:${C_RESET} ${C_YELLOW}${TEST_REL}${C_RESET}"
    echo -e "${C_CYAN}------------------------------------------------------------${C_RESET}"
  fi

  if [ "$PUSH_TO_DOCKERHUB" = "true" ]; then
    log_step "Pushing to Docker Hub: ${FULL_IMAGE_TAG}"
    log_exec "docker push ${FULL_IMAGE_TAG}"
    docker push "${FULL_IMAGE_TAG}"
    for extra_tag in "${ALL_EXTRA_TAGS[@]}"; do
      docker push "${IMAGE_NAME}:${extra_tag}-${PRESET_CHOICE}"
    done
  fi

  if [ "$PUSH_TO_GHCR" = "true" ]; then
    log_step "Pushing to GHCR: ${FULL_GHCR_TAG}"
    log_exec "docker push ${FULL_GHCR_TAG}"
    docker push "${FULL_GHCR_TAG}"
    for extra_tag in "${ALL_EXTRA_TAGS[@]}"; do
      docker push "${GHCR_IMAGE_NAME}:${extra_tag}-${PRESET_CHOICE}"
    done
  fi

  SUCCESS_TAGS+=("${FULL_IMAGE_TAG}")
  cleanup_run
  trap - EXIT
done

echo ""
echo -e "${C_BOLD}==============================================================================${C_RESET}"
echo -e "${C_GREEN}${C_BOLD}BUILD SUMMARY REPORT${C_RESET}"
echo -e "Images successfully built: ${#SUCCESS_TAGS[@]}"
for t in "${SUCCESS_TAGS[@]}"; do
  echo -e "  - ${C_BOLD}${t}${C_RESET}"
done
echo -e "${C_BOLD}==============================================================================${C_RESET}"
