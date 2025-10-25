#!/usr/bin/env bash
# clear-longhorn-devices.sh v1.1
# Safely clean leftover Longhorn devices & data. Skips detaching real disks (sd*/nvme*).

set -Eeuo pipefail

DRY_RUN=0
PRESERVE_DATA=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --preserve-data) PRESERVE_DATA=1 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done
log()  { echo -e "[INFO] $*"; }
warn() { echo -e "[WARN] $*" >&2; }
run()  { if [ "$DRY_RUN" -eq 1 ]; then echo "[DRY] $*"; else eval "$@"; fi; }

require_root() { if [ "${EUID:-$(id -u)}" -ne 0 ]; then warn "Please run as root (sudo)."; exit 1; fi; }

# Return canonical kernel name for a devnode (e.g. sdX, nvme0n1, dm-3, loop2, nbd0)
kernel_name_for() {
  local dev="$1"
  lsblk -no KNAME "$dev" 2>/dev/null | head -n1
}

# Decide if it's safe to detach via sysfs (loop/dm/nbd only)
is_detachable_kind() {
  case "$1" in
    loop*|dm-*|nbd*) return 0 ;;
    *) return 1 ;;
  esac
}

# Detach a device via its /sys/dev/block/MAJ:MIN only if it's loop/dm/nbd
safe_detach_sysfs() {
  local devnode="$1"
  [ -e "$devnode" ] || return 0
  local kname; kname="$(kernel_name_for "$devnode")"
  if [ -z "$kname" ]; then
    warn "Cannot determine kernel name for $devnode; skipping detach."
    return 0
  fi
  if ! is_detachable_kind "$kname"; then
    log "Skipping detach for $devnode (kernel device is '$kname', likely a real disk)."
    return 0
  fi
  # Compute MAJ:MIN
  local maj_hex min_hex maj min sys
  maj_hex=$(stat -c %t "$devnode"); min_hex=$(stat -c %T "$devnode")
  maj=$((16#$maj_hex)); min=$((16#$min_hex))
  sys="/sys/dev/block/${maj}:${min}"
  if [ -e "$sys/device/delete" ]; then
    log "Detaching kernel device $kname for $devnode via $sys/device/delete"
    run "echo 1 > '$sys/device/delete'"
  else
    warn "No sysfs delete at $sys for $devnode; skipping."
  fi
}

main() {
  require_root
  log "Starting Longhorn cleanup (dry-run=${DRY_RUN}, preserve-data=${PRESERVE_DATA})"

  # 0) Mount scan
  if mount | egrep -q 'longhorn|longhorn\.csi\.k8s\.io'; then
    warn "Found Longhorn-related mounts:"; mount | egrep 'longhorn|longhorn\.csi\.k8s\.io' || true
  else
    log "No Longhorn mounts detected."
  fi

  # 1) Device-mapper maps with 'longhorn' (often none on a cleaned node)
  if command -v dmsetup >/dev/null 2>&1; then
    maps="$(dmsetup ls 2>/dev/null | awk '/longhorn/{print $1}' || true)"
    if [ -n "${maps:-}" ]; then
      log "Removing device-mapper maps referencing 'longhorn':"
      while read -r name; do [ -z "$name" ] && continue; log "dmsetup remove -f '$name'"; run "dmsetup remove -f '$name' || true"; done <<< "$maps"
    else
      log "No device-mapper entries with 'longhorn' found."
    fi
  else
    warn "dmsetup not found; skipping DM cleanup."
  fi

  # 2) Detach loop devices for replica heads (if any)
  if command -v losetup >/dev/null 2>&1; then
    shopt -s nullglob
    imgs=(/var/lib/longhorn/replicas/*/volume-head-000.img)
    if [ "${#imgs[@]}" -gt 0 ]; then
      for f in "${imgs[@]}"; do
        lps="$(losetup -j "$f" | awk -F: '{print $1}')"
        [ -n "${lps:-}" ] || continue
        while read -r lp; do [ -z "$lp" ] && continue; log "Detaching loop device $lp (backing $f)"; run "losetup -d '$lp' || true"; done <<< "$lps"
      done
    else
      log "No Longhorn replica head images found (loop detach not needed)."
    fi
    shopt -u nullglob
  else
    warn "losetup not found; skipping loop device check."
  fi

  # 3) If /dev/longhorn exists: unmount (just in case) and handle its block nodes safely
  if [ -d /dev/longhorn ]; then
    mountpoint -q /dev/longhorn && { log "Unmounting /dev/longhorn"; run "umount -l /dev/longhorn || true"; }
    nodes=$(find /dev/longhorn -maxdepth 1 -type b -printf "%p\n" 2>/dev/null || true)
    if [ -n "${nodes:-}" ]; then
      log "Reviewing block devices exposed in /dev/longhorn:"
      while read -r dev; do
        [ -z "$dev" ] && continue
        kname="$(kernel_name_for "$dev")"
        log " - $dev → kernel='$kname'"
        safe_detach_sysfs "$dev"
      done <<< "$nodes"
    else
      log "/dev/longhorn contains no block devices."
    fi
    log "Removing /dev/longhorn directory"
    run "rm -rf /dev/longhorn"
  else
    log "/dev/longhorn does not exist (good)."
  fi

  # 4) Remove Longhorn data directory unless preserved
  if [ "$PRESERVE_DATA" -eq 0 ]; then
    if [ -e /var/lib/longhorn ]; then
      log "Removing /var/lib/longhorn (data & binaries)"
      run "rm -rf /var/lib/longhorn"
    else
      log "/var/lib/longhorn not present."
    fi
  else
    warn "Preserving /var/lib/longhorn (per --preserve-data)."
  fi

  # 5) Final checks
  [ -d /dev/longhorn ] && warn "/dev/longhorn still exists." || log "OK: /dev/longhorn removed."
  if [ -d /var/lib/longhorn ]; then
    [ "$PRESERVE_DATA" -eq 1 ] && warn "/var/lib/longhorn preserved." || warn "/var/lib/longhorn still exists (removal failed)."
  else
    [ "$PRESERVE_DATA" -eq 1 ] || log "OK: /var/lib/longhorn removed."
  fi
  log "Done."
}

main "$@"
