# Proxmox VE 9 boot loop on Dell PowerEdge R730

## Decision record

Affected systems can reset while the PVE 9 installer or an installed PVE 9
system boots a 6.17 PVE kernel. Reports describe MCE/hardware events even when
memory and CPU diagnostics pass. The practical remediation is platform
firmware configuration:

1. Update supported Dell firmware.
2. Enable X2APIC Mode and I/OAT DMA Engine.
3. Enable SR-IOV Global, as recommended in the PVE 9.1 known-issues guidance.
4. Cold-power-cycle the server.
5. Retest the official ISO or installed 6.17 kernel.

A known-good 6.14/6.8 PVE kernel may be retained and pinned for recovery. It is
not automatically applied because kernel availability differs by installation,
and silently pinning an old kernel would defer security and maintenance updates.

## Repository implementation

- `overlays/dell-r730-pve9/README.md` is the operator runbook.
- `scripts/r730-pve9-preflight.sh` performs read-only detection by default.
- `--apply-kernel-pin` is an explicit, guarded recovery action.

The overlay intentionally does not patch the Proxmox kernel or redistribute a
modified installer ISO. The documented resolution is a Dell firmware setting,
and using the official installation artifacts preserves their verification and
upgrade path.

## Upstream references

- Proxmox VE 9.1 known issues:
  https://pve.proxmox.com/wiki/Roadmap#9.1-known-issues
- Proxmox forum, solved R730 boot loop:
  https://forum.proxmox.com/threads/dell-r730-cannot-boot-proxmox-9-kernel-boot-loop-after-install.183355/
- Proxmox bug 6950:
  https://bugzilla.proxmox.com/show_bug.cgi?id=6950
