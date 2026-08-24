# RED OS ISO to Docker Patch Images

[![Build and Push RED OS Docker Images](https://github.com/runalsh/redos-iso-patch/actions/workflows/build.yml/badge.svg)](https://github.com/runalsh/redos-iso-patch/actions/workflows/build.yml)

Automated Docker images for exact RED OS releases (**7.3.0**–**7.3.7**, **8.0.0**–**8.0.3**) with systemd support, built directly from official Everything DVD ISOs into **`runalsh/redos-iso-patch`** and **`ghcr.io/runalsh/redos-iso-patch`**.

---

## ❓ Problem Statement

Official RED OS container images distributed on `registry.red-soft.ru` (such as `ubi8/ubi` or `ubi7/ubi`) are heavily stripped down:
- They **lack `systemd` / PID 1 init support** (`systemctl` fails with errors).
- They **miss essential server administration tools** (`sudo`, `tar`, `iproute`, `sysctl`, `procps-ng`).
- They differ in base package dependencies compared to real Hyper-V / KVM virtual machines, causing Ansible deployment roles to fail.

This project builds full-featured Docker images directly from official Everything ISOs, strips non-container hardware bloat, and provides out-of-the-box support for **`systemd` (PID 1)**.

---

## 📦 Available Images and Registries

### RED OS 8.0 (Minimal Preset Example)

| Tag | Semantic Version | Docker Hub Image Link | GHCR Package Link |
|---|---|---|---|
| `8-minimal` | RED OS 8.0 (Latest Major) | [`runalsh/redos-iso-patch:8-minimal`](https://hub.docker.com/r/runalsh/redos-iso-patch/tags) | [`ghcr.io/runalsh/redos-iso-patch:8-minimal`](https://github.com/users/runalsh/packages/container/package/redos-patch) |
| `8.0-minimal` | RED OS 8.0 (Minor) | [`runalsh/redos-iso-patch:8.0-minimal`](https://hub.docker.com/r/runalsh/redos-iso-patch/tags) | [`ghcr.io/runalsh/redos-iso-patch:8.0-minimal`](https://github.com/users/runalsh/packages/container/package/redos-patch) |
| `8.0.3-minimal` | RED OS 8.0.3 (Patch) | [`runalsh/redos-iso-patch:8.0.3-minimal`](https://hub.docker.com/r/runalsh/redos-iso-patch/tags) | [`ghcr.io/runalsh/redos-iso-patch:8.0.3-minimal`](https://github.com/users/runalsh/packages/container/package/redos-patch) |
| `8.0.2-minimal` | RED OS 8.0.2 (Patch) | [`runalsh/redos-iso-patch:8.0.2-minimal`](https://hub.docker.com/r/runalsh/redos-iso-patch/tags) | [`ghcr.io/runalsh/redos-iso-patch:8.0.2-minimal`](https://github.com/users/runalsh/packages/container/package/redos-patch) |
| `8.0.1-minimal` | RED OS 8.0.1 (Patch) | [`runalsh/redos-iso-patch:8.0.1-minimal`](https://hub.docker.com/r/runalsh/redos-iso-patch/tags) | [`ghcr.io/runalsh/redos-iso-patch:8.0.1-minimal`](https://github.com/users/runalsh/packages/container/package/redos-patch) |
| `8.0.0-minimal` | RED OS 8.0.0 (Patch) | [`runalsh/redos-iso-patch:8.0.0-minimal`](https://hub.docker.com/r/runalsh/redos-iso-patch/tags) | [`ghcr.io/runalsh/redos-iso-patch:8.0.0-minimal`](https://github.com/users/runalsh/packages/container/package/redos-patch) |

### RED OS 7.3 (Minimal Preset Example)

| Tag | Semantic Version | Docker Hub Image Link | GHCR Package Link |
|---|---|---|---|
| `7-minimal` | RED OS 7.3 (Latest Major) | [`runalsh/redos-iso-patch:7-minimal`](https://hub.docker.com/r/runalsh/redos-iso-patch/tags) | [`ghcr.io/runalsh/redos-iso-patch:7-minimal`](https://github.com/users/runalsh/packages/container/package/redos-patch) |
| `7.3-minimal` | RED OS 7.3 (Minor) | [`runalsh/redos-iso-patch:7.3-minimal`](https://hub.docker.com/r/runalsh/redos-iso-patch/tags) | [`ghcr.io/runalsh/redos-iso-patch:7.3-minimal`](https://github.com/users/runalsh/packages/container/package/redos-patch) |
| `7.3.7-minimal` | RED OS 7.3.7 (Patch) | [`runalsh/redos-iso-patch:7.3.7-minimal`](https://hub.docker.com/r/runalsh/redos-iso-patch/tags) | [`ghcr.io/runalsh/redos-iso-patch:7.3.7-minimal`](https://github.com/users/runalsh/packages/container/package/redos-patch) |
| `7.3.6-minimal` | RED OS 7.3.6 (Patch) | [`runalsh/redos-iso-patch:7.3.6-minimal`](https://hub.docker.com/r/runalsh/redos-iso-patch/tags) | [`ghcr.io/runalsh/redos-iso-patch:7.3.6-minimal`](https://github.com/users/runalsh/packages/container/package/redos-patch) |
| `7.3.5-minimal` | RED OS 7.3.5 (Patch) | [`runalsh/redos-iso-patch:7.3.5-minimal`](https://hub.docker.com/r/runalsh/redos-iso-patch/tags) | [`ghcr.io/runalsh/redos-iso-patch:7.3.5-minimal`](https://github.com/users/runalsh/packages/container/package/redos-patch) |
| `7.3.4-minimal` | RED OS 7.3.4 (Patch) | [`runalsh/redos-iso-patch:7.3.4-minimal`](https://hub.docker.com/r/runalsh/redos-iso-patch/tags) | [`ghcr.io/runalsh/redos-iso-patch:7.3.4-minimal`](https://github.com/users/runalsh/packages/container/package/redos-patch) |
| `7.3.3-minimal` | RED OS 7.3.3 (Patch) | [`runalsh/redos-iso-patch:7.3.3-minimal`](https://hub.docker.com/r/runalsh/redos-iso-patch/tags) | [`ghcr.io/runalsh/redos-iso-patch:7.3.3-minimal`](https://github.com/users/runalsh/packages/container/package/redos-patch) |
| `7.3.2-minimal` | RED OS 7.3.2 (Patch) | [`runalsh/redos-iso-patch:7.3.2-minimal`](https://hub.docker.com/r/runalsh/redos-iso-patch/tags) | [`ghcr.io/runalsh/redos-iso-patch:7.3.2-minimal`](https://github.com/users/runalsh/packages/container/package/redos-patch) |
| `7.3.1-minimal` | RED OS 7.3.1 (Patch) | [`runalsh/redos-iso-patch:7.3.1-minimal`](https://hub.docker.com/r/runalsh/redos-iso-patch/tags) | [`ghcr.io/runalsh/redos-iso-patch:7.3.1-minimal`](https://github.com/users/runalsh/packages/container/package/redos-patch) |
| `7.3.0-minimal` | RED OS 7.3.0 (Patch) | [`runalsh/redos-iso-patch:7.3.0-minimal`](https://hub.docker.com/r/runalsh/redos-iso-patch/tags) | [`ghcr.io/runalsh/redos-iso-patch:7.3.0-minimal`](https://github.com/users/runalsh/packages/container/package/redos-patch) |

### Universal Presets Mapping

| Preset Name | RED OS 8.0 Group | RED OS 7.3 Group | Description |
|---|---|---|---|
| **`minimal`** *(default)* | `server-minimal-environment` | `server-minimal` | Clean, headless server base with `systemd` and standard server tools. |
| **`server`** | `server-product-environment` | `graphical-server-environment` | Full server environment including administrative services. |
| **`workstation`** | `workstation-product-environment` | `desktop-environment` | Complete workstation suite. |

---

## ✂️ What is Stripped from the ISO (Size Optimization)

A full RED OS Everything ISO is **5–6 GB**. After `dnf --installroot` and container-tailored optimizations, the final Docker image is reduced to **~430 MB** (and **~125 MB** compressed on registry push).

| Component / Path | What it is | Why it is safe to remove in Docker | Disk Space Saved |
|---|---|---|---|
| **`kernel-lt` / `kernel`** (`/boot`, `/lib/modules`) | Linux kernel binary and module drivers | Containers share the host OS kernel; internal kernel files are never loaded. | **~445 MB** |
| **`*-firmware`** (`linux-firmware`, `atheros`, `amd-gpu`, `nvidia`, `intel`, `realtek`) | Hardware device firmware for GPUs, Wi-Fi, audio | Containers do not manage bare-metal hardware. | **~370 MB** |
| **Non-English Locales** (`/usr/share/locale/*`) | System translation files for hundreds of languages | Standard container runtime strictly uses `en_US.UTF-8` / `POSIX`. | **~120 MB** |
| **Documentation & Manuals** (`/usr/share/{doc,man,info}`) | Package READMEs, changelogs, man pages | Not used by automated daemons or CI/CD pipelines (`tsflags=nodocs`). | **~180 MB** |
| **Scheme Interpreter** (`guile22`, `/usr/lib64/guile`) | GNU Guile 2.2 Lisp runtime | Has **0 reverse dependencies** in the base system. | **~44 MB** |
| **Build Tools** (`binutils`, `binutils-gold`) | Linkers and assemblers (`ld`, `as`, `objdump`) | Not required for runtime. Can be installed via `dnf install gcc` if needed. | **~25 MB** |
| **Disk Bootloaders** (`grub2-*`, `grubby`, `systemd-boot-unsigned`) | Bootloader configuration for MBR/GPT/EFI | Containers are spawned via `runc` / host kernel without BIOS/EFI. | **~28 MB** |
| **Firmware Updater** (`fwupd`) | Motherboard BIOS / UEFI flashing daemon | Container has no access to physical flash chips. | **~7.5 MB** |
| **Hardware Database** (`/etc/udev/hwdb.bin`) | PCI/USB device identification database | Not needed inside virtual container namespaces. | **~12 MB** |
| **Python Test Suites** (`/usr/lib64/python*/test`) | Standard library unit test suites | Development tests not required in runtime. | **~25 MB** |
| **Package Caches & Logs** (`/var/cache/dnf`, `/var/log/*`, `/tmp/*`) | RPM/DNF metadata cache and install logs | Re-generated on demand during `dnf update`. | **~50 MB** |
| **Total Savings** | | | **~1.3 GB (Rootfs) / ~5.5 GB (ISO)** |

---

## ⚡ Systemd (PID 1) Compatibility

- Unnecessary hardware getty consoles (`getty.target`, `systemd-logind.service`, `sockets.target.wants/*udev*`) are masked.
- Container environment is flagged with `container=docker` and `STOPSIGNAL SIGRTMIN+3`.
- Running with `/sbin/init` achieves full `systemctl is-system-running -> running` state.
- RPM database is pre-migrated to SQLite backend with distribution GPG keys preloaded.

---

## 🛠 Quick Start

### 1. Run container in background with Systemd:

```bash
docker run -d --name redos \
  --privileged \
  --cgroupns=host \
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
  ghcr.io/runalsh/redos-iso-patch:8-minimal
```

### 2. Connect into interactive shell:

```bash
docker exec -it redos bash
```

### 3. Verify systemd:

```bash
systemctl is-system-running
# Output: running

systemctl status
```

---

## 🐳 Optional: Running Docker inside Container (Docker-in-Docker / DinD)

If your workflow requires running the Docker daemon (`docker-ce`) inside the RED OS container, follow these 3 steps inside the container:

### 1. Install Docker:
```bash
dnf install -y docker-ce
```

### 2. Override containerd `modprobe` check and configure driver:
Containers cannot load host kernel modules directly. Bypass the `modprobe` check and enable the `vfs` storage driver:

```bash
# 1. Bypass ExecStartPre modprobe in containerd
mkdir -p /etc/systemd/system/containerd.service.d
cat << 'EOF' > /etc/systemd/system/containerd.service.d/override.conf
[Service]
ExecStartPre=
