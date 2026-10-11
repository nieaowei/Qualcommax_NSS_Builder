#!/usr/bin/env bash
# Minimal OpenWrt/NSS source builder. Linux x86_64 and Linux ARM64 hosts.
set -euo pipefail
usage() { echo 'Usage: JOBS=6 bash scripts/build-local.sh [mx4200v1|mx5300|all]'; }
device="${1:-all}"
case "$device" in
  mx4200v1|mx5300|all) ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac
[[ $# -le 1 ]] || { usage >&2; exit 2; }
if [[ "$(uname -s)" != Linux ]]; then
  echo '[ERROR] Linux host required. On Apple Silicon use an Ubuntu ARM64 virtual machine.' >&2
  exit 1
fi
jobs="${JOBS:-6}"
[[ "$jobs" =~ ^[1-9][0-9]*$ ]] || { echo '[ERROR] JOBS must be positive integer' >&2; exit 2; }
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="${WORK_ROOT:-$root/work}"
upstream_ref="${OPENWRT_REF:-nss-edma-rework}"
mkdir -p "$work/dl" "$root/output"
for prog in git make patch rsync sha256sum find; do
  command -v "$prog" >/dev/null || { echo "[ERROR] missing $prog" >&2; exit 1; }
done

build_one() {
  local model="$1" id src out
  local -a images
  case "$model" in
    mx4200v1) id=linksys_mx4200v1 ;;
    mx5300) id=linksys_mx5300 ;;
    *) return 2 ;;
  esac
  src="$work/openwrt-$model"
  out="$root/output/$model"
  mkdir -p "$out"
  if [[ -d "$src/.git" ]]; then
    echo "[INFO] updating $model source (managed tree; local edits will be reset)"
    git -C "$src" fetch --depth 1 origin "$upstream_ref"
    git -C "$src" reset --hard FETCH_HEAD
  elif [[ -e "$src" ]]; then
    echo "[ERROR] unexpected source directory: $src" >&2; return 1
  else
    git clone --depth 1 --branch "$upstream_ref" \
      https://github.com/JuliusBairaktaris/openwrt-nss-edma.git "$src"
  fi
  # Source downloads are shared, but compiled kernels/modules are NOT.
  if [[ ! -e "$src/dl" && ! -L "$src/dl" ]]; then
    ln -s "$work/dl" "$src/dl"
  elif [[ -d "$src/dl" && ! -L "$src/dl" ]]; then
    rmdir "$src/dl" 2>/dev/null && ln -s "$work/dl" "$src/dl" || true
  fi
  echo "[INFO] preparing $model (jobs=$jobs)"
  OPENWRT_DIR="$src" BUILDER_REPO="$root" VARIANT=edma-nss DEVICE="$model" \
    FEEDS='src-git nss https://github.com/JuliusBairaktaris/nss-packages.git;edma-nss' \
    bash "$root/scripts/prepare-build.sh"
  (cd "$src" && make download -j"$jobs" V=s)
  (cd "$src" && make -j"$jobs")
  local bindir="$src/bin/targets/qualcommax/ipq807x"
  [[ -d "$bindir" ]] || { echo "[ERROR] no firmware output: $bindir" >&2; return 1; }
  mapfile -d '' -t images < <(find "$bindir" -maxdepth 1 -type f -name "*$id-squashfs-sysupgrade.bin" -print0)
  if [[ ${#images[@]} -ne 1 ]]; then
    echo "[ERROR] expected 1 $id image, found ${#images[@]}" >&2
    return 1
  fi
  cp "${images[0]}" "$out/"
  (cd "$out"; sha256sum "$(basename "${images[0]}")" > "sha256sums-$model.txt")
  [[ ! -f "$bindir/config.buildinfo" ]] || cp "$bindir/config.buildinfo" "$out/config-$model.buildinfo"
  echo "[INFO] done: $out"
}
case "$device" in
  all) build_one mx4200v1; build_one mx5300 ;;
  *) build_one "$device" ;;
esac
