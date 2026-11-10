# MX4200 v1 NSS OpenWrt Builder

This fork builds **only Linksys MX4200 v1 (512 MiB RAM)** using
[JuliusBairaktaris/openwrt-ppe-nss](https://github.com/JuliusBairaktaris/openwrt-ppe-nss)
(`ppe-nss` branch). It retains NSS Wi-Fi offload and the existing
PPE-based wired offload.

## What changed

- **Single target:** `Build` uses only `ipq807x-6m-kernel`, and the
  group config now selects only `linksys_mx4200v1`. Other inherited device
  config files are inactive, not removed.
- **Low-memory ath11k:** `DP_RXDMA_BUF_RING_SIZE` and
  `DP_RXDMA_MONITOR_DESC_RING_SIZE` shrink from 4096 to 2048. The refill
  buffer length and NSS offload paths remain unchanged.
- **Detached BTF:** pins
  [QiuSimons/vmlinux-btf](https://github.com/QiuSimons/vmlinux-btf)
  to `b41770520cef00652738cdfbbdda44d4de77f3f5`, installs it as
  `CONFIG_PACKAGE_vmlinux-btf=y`, and provides `pahole` via the Ubuntu
  `dwarves` build dependency.
- **6 MiB kernel partition:** keeps REGULAR stack protection.
  `CONFIG_KERNEL_DEBUG_INFO_BTF` is **not enabled** to avoid enlarging the
  compressed FIT kernel image.

## Build

Use [Actions → Build](https://github.com/nieaowei/Qualcommax_NSS_Builder/actions/workflows/build.yml)
to run the workflow after merging into `main`. Scheduled builds only
rebuild when upstream sources move. On success, the firmware is published
under [Releases](https://github.com/nieaowei/Qualcommax_NSS_Builder/releases).

The workflow enforces exactly one `linksys_mx4200v1` sysupgrade image.
Only flash `*linksys_mx4200v1*squashfs-sysupgrade.bin` over an existing
MX4200 v1 OpenWrt installation. **Never use this image on MX4200 v2,
MX5300, MX8500, or MX4300.** Confirm the compressed kernel fits the
6 MiB partition before flashing.

## Verify on the router

```sh
grep -E 'MemAvailable|Slab|SUnreclaim' /proc/meminfo
ls -l /usr/lib/debug/boot/vmlinux*
dmesg | grep -Ei 'ath11k|nss|oom|allocation'
```

The detached BTF package generates type data from headers/config, not the
running kernel's full embedded BTF; `/sys/kernel/btf/vmlinux` may still
be absent. Test compatibility with the exact eBPF CO-RE application you use.

The ppe-nss tree does not expose
`CPTCFG_ATH11K_MEM_PROFILE_512M`. Consequently, the supplied
conditional patch would be inactive there. The **2048-entry values
are unconditional only within this single-device build**.

The old multi-device configuration directories and ancillary custom image
and site workflows remain for reference; only the primary `Build`
workflow is restricted to MX4200 v1. See [docs/CUSTOMIZE.md](docs/CUSTOMIZE.md)
for other build details.
