# ath11k NSS RX memory tuning (512 MB IPQ807x)

This experimental change targets the `ipq807x-512m` build group (including
Linksys MX4200 v1). The builder preserves the existing
`CONFIG_ATH11K_MEM_PROFILE_512M=y` and
`CONFIG_NSS_MEM_PROFILE_MEDIUM=y` settings and NSS Wi-Fi offload.

## What changes

The upstream NSS ath11k patches **already** reduce monitor status/buffer/dst
rings on 512 MB builds to 512/128/128, and TX completion to 8192.
Do not reapply the full five-ring stock-ath11k halving patch.

The extra late NSS backports patch alters only:

| Symbol | Previous | New on 512M | Other profiles |
| --- | ---: | ---: | --- |
| `DP_RXDMA_BUF_RING_SIZE` | 4096 | 2048 | unchanged |
| `DP_RXDMA_MONITOR_DESC_RING_SIZE` | 4096 | 2048 | unchanged |

In particular, it does **not** change `DP_RXDMA_REFILL_RING_SIZE`, the
RX buffer length communicated to firmware, or
`DP_RXDMA_NSS_REFILL_RING_SIZE`. NSS Wi-Fi offload stays enabled.

The patch is nested in
`patches/tree/edma-nss/0001-mac80211-ath11k-512m-rx-rings.patch`.
`scripts/prepare-build.sh` adds its inner patch under the upstream
`package/kernel/mac80211/patches/nss/ath11k/` directory before compilation.
The inner patch is applied **after** existing NSS memory profile patches
as part of mac80211's `Build/Patch` process.

## Verification before deployment

The change has been reviewed against the upstream source patch definitions
but **has not been compiled or tested on hardware**. Before flashing:

1. Run the usual `edma-nss` build for `ipq807x-512m` and confirm the
   package/kernel/mac80211 patch step succeeds for both default and mesh.
2. Inspect the prepared backports tree for
   `DP_RXDMA_BUF_RING_SIZE` and `DP_RXDMA_MONITOR_DESC_RING_SIZE`.
   Check both evaluate to 2048 with `CPTCFG_ATH11K_MEM_PROFILE_512M`.
3. Check the resulting image still includes ath11k NSS and the 512 MB
   firmware profile. Back up the previous, working image.
4. After flashing, compare `/proc/meminfo` (`MemAvailable`, `Slab`,
   `SUnreclaim`), Wi-Fi stability/throughput, and `nss-status` under
   the same client and load conditions.
5. Test throughput, client association, recovery after wireless restart,
   and the actual NSS data path over multiple hours.

Potential regressions include packet drops or throughput degradation
under heavy load. Ring reduction limits buffering capacity; it is not
a proven fix for every page-frag or DMA memory issue.

## Revert

Revert the builder commit containing the outer patch and rebuild.
Use a previously working sysupgrade image if wireless fails or NSS
offload becomes unstable.

References:
- https://github.com/openwrt/openwrt/issues/24154
- https://github.com/enspect/ath11k-ipq807x-rx-buffer-oom-fix
