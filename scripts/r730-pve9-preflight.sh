#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: r730-pve9-preflight.sh [--check|--apply-kernel-pin]

  --check             Detect affected hardware/kernel and print remediation.
  --apply-kernel-pin  Pin the newest installed 6.14 or 6.8 PVE fallback kernel.
EOF
}

mode="--check"
if [[ $# -gt 1 ]]; then usage >&2; exit 2; fi
if [[ $# -eq 1 ]]; then mode="$1"; fi
case "$mode" in --check|--apply-kernel-pin) ;; *) usage >&2; exit 2 ;; esac

read_dmi() {
  local name="$1"
  if [[ -r "/sys/class/dmi/id/$name" ]]; then
    tr -d '\000' < "/sys/class/dmi/id/$name"
  fi
}

vendor="$(read_dmi sys_vendor)"
product="$(read_dmi product_name)"
kernel="$(uname -r)"

printf 'Vendor:  %s\nModel:   %s\nKernel:  %s\n'   "${vendor:-unknown}" "${product:-unknown}" "$kernel"

if [[ "$vendor" != *Dell* || ! "$product" =~ PowerEdge[[:space:]]R730(xd)? ]]; then
  echo "Result: this host is not identified as a Dell PowerEdge R730/R730xd."
  exit 0
fi

echo "Result: Dell PowerEdge R730-family host detected."

if [[ "$kernel" == 6.17.*-pve ]]; then
  echo "Warning: kernel 6.17 is associated with boot loops/MCEs on some R730 systems."
fi

cat <<'EOF'

Before booting kernel 6.17, update Dell platform firmware and enable:
  - X2APIC Mode
  - I/OAT DMA Engine
  - SR-IOV Global Enable (recommended)

Perform a cold power cycle after saving firmware settings.
EOF

if command -v journalctl >/dev/null 2>&1; then
  if journalctl -k -b --no-pager 2>/dev/null |
      grep -Eiq 'machine check|hardware error|mce:'; then
    echo "Warning: this boot contains possible machine-check/hardware-error records."
  else
    echo "No machine-check signature was found in the readable current-boot log."
  fi
fi

mapfile -t fallbacks < <(
  find /boot -maxdepth 1 -type f -name 'vmlinuz-*-pve' -printf '%f\n' 2>/dev/null |
    sed 's/^vmlinuz-//' |
    grep -E '^(6\.14|6\.8)\..*-pve$' |
    sort -V
)
fallback=""
if (("${#fallbacks[@]}" > 0)); then
  fallback="${fallbacks[-1]}"
  echo "Newest installed fallback kernel: $fallback"
else
  echo "No installed 6.14/6.8 PVE fallback kernel was found."
fi

if [[ "$mode" == "--check" ]]; then
  exit 0
fi

if [[ -z "$fallback" ]]; then
  echo "Cannot pin: install a known-good PVE fallback kernel first." >&2
  exit 1
fi
if [[ $EUID -ne 0 ]]; then
  echo "Kernel pinning requires root." >&2
  exit 1
fi
if ! command -v proxmox-boot-tool >/dev/null 2>&1; then
  echo "proxmox-boot-tool is unavailable; refusing to modify boot configuration." >&2
  exit 1
fi

proxmox-boot-tool kernel pin "$fallback"
echo "Pinned $fallback. Correct the firmware configuration before unpinning."
