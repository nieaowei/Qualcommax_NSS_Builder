# Linksys NSS Builder

Minimal builder for **Linksys MX4200 v1** and **Linksys MX5300**. Uses
[JuliusBairaktaris/openwrt-nss-edma](https://github.com/JuliusBairaktaris/openwrt-nss-edma)
(branch `nss-edma-rework`) and
[nss-packages](https://github.com/JuliusBairaktaris/nss-packages) (branch `edma-nss`).

| Device | RAM | ath11k | NSS memory | Experimental RX ring patch |
|---|---:|---|---|---|
| MX4200 v1 | 512 MB | 512M | MEDIUM | Enabled |
| MX5300 | 1 GB | 1G | HIGH | Not enabled |

The two models are compiled in **separate build trees** because ath11k/NSS memory profiles are compile-time.
All original NSS Wi-Fi offload, ECM, PPPoE, bridge and NSS SQM settings are retained.
Images are **sysupgrade only**, not factory images. No 802.11s mesh-only variant.

## Linux / Apple Silicon Ubuntu VM local builds

The local script requires **Linux**, not native macOS. On an M1 Max with
64 GB RAM, Ubuntu ARM64 in UTM or VMware Fusion is the recommended experiment:
allocate roughly 6–8 vCPUs, 24–32 GB RAM and 150–200 GB free disk for both
images. The exact NSS toolchain on a Linux ARM64 build host is **not yet verified**.

Install host dependencies in Ubuntu:

~~~bash
sudo apt-get update
sudo apt-get install -y \
  build-essential bzip2 clang flex bison gawk gcc git \
  libncurses-dev libssl-dev libelf-dev zlib1g-dev \
  make patch python3 rsync unzip wget curl file xz-utils \
  gettext cmake ninja-build pkg-config
~~~

Build:

~~~bash
# clone this project at its final GitHub repository URL
JOBS=6 bash scripts/build-local.sh mx4200v1
JOBS=6 bash scripts/build-local.sh mx5300
# or build both sequentially:
JOBS=6 bash scripts/build-local.sh all
~~~

Sources are checked out under `work/openwrt-<device>`, downloads reused
in `work/dl`, and images placed under `output/<device>/`.
Set `WORK_ROOT=/path/to/storage` for a different work directory.
The script resets the **managed** OpenWrt checkout to the latest upstream
branch on each run; do not edit files under `work/`.
For verbose build errors, from the corresponding source tree run
`make -j1 V=s`.

## GitHub Actions

The workflow uses two matrix jobs: only MX4200 v1 and MX5300. Trigger with
Actions -> Build Linksys NSS -> Run workflow, or by pushing build-related
changes to main. No scheduled builds, download-statistics job, PPE test
variants or unrelated router configs. If both builds pass, publish
two images as a GitHub Release plus temporary workflow artifacts.

## Memory optimization and risks

MX4200 v1 carries the experimental ath11k 512M RX-ring adjustment from
the earlier builder. It reduces the two remaining 4096-entry RX-related
rings to 2048 and does not touch the RX firmware buffer length.
The 1G MX5300 profile is unchanged by this patch.
Details: https://github.com/openwrt/openwrt/issues/24154

The new minimized repository and Ubuntu ARM64 local build path are **not
yet compile-tested**. Save known-working firmware before upgrading.
Confirm memory availability, Wi-Fi stability and `nss-status` under load.

## Credits and license

Derived from [JuliusBairaktaris/Qualcommax_NSS_Builder](https://github.com/JuliusBairaktaris/Qualcommax_NSS_Builder)
and [nieaowei/Qualcommax_NSS_Builder](https://github.com/nieaowei/Qualcommax_NSS_Builder).
GPL-2.0-only; see LICENSES/GPL-2.0 and upstream package licensing.
