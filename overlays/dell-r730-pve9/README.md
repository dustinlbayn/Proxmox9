# Dell PowerEdge R730/R730xd — Proxmox VE 9 boot workaround

## Scope

This overlay addresses an observed boot loop on some 13th-generation Dell
PowerEdge R730/R730xd systems when the Proxmox VE 9 installer or installed
system starts a Linux 6.17 PVE kernel. Typical symptoms include an immediate
reset near `waiting for /dev to be fully populated`, Machine Check Exceptions,
and Dell lifecycle-controller hardware events after the reset.

This is a firmware/kernel interaction, not evidence that the reported CPU,
memory, or PERC hardware has failed.

## Required firmware configuration

Update the BIOS, iDRAC, Lifecycle Controller, PERC, NIC, and CPU microcode to
the newest versions Dell supports for the service tag. Then open:

`System Setup → System BIOS → Integrated Devices / Processor Settings`

Enable these settings (wording varies by BIOS revision):

- **X2APIC Mode**
- **I/OAT DMA Engine**
- **SR-IOV Global Enable** (recommended by the Proxmox 9.1 known-issues note)

Save the configuration, perform a full cold power cycle, and retry the official
Proxmox VE installer. Do not merely warm-reboot: remove standby power for about
30 seconds if the machine continues to retain the previous platform state.

## Recovery when Proxmox is already installed

If an older PVE kernel remains in the boot menu:

1. Select **Advanced options for Proxmox VE** in GRUB.
2. Boot a known-working 6.14 or 6.8 PVE kernel.
3. Run `sudo scripts/r730-pve9-preflight.sh --check`.
4. If needed, explicitly pin the displayed fallback with
   `sudo scripts/r730-pve9-preflight.sh --apply-kernel-pin`.
5. Apply the firmware settings above before attempting kernel 6.17 again.

Kernel pinning is a recovery measure, not the preferred permanent solution.
The script never changes firmware and never pins a kernel without the explicit
`--apply-kernel-pin` option.

## Installer cannot reach a shell

Change the firmware settings before booting the ISO. If that is impossible,
use an older installer/kernel only as a recovery path, update the platform
firmware and settings, and then upgrade normally. Rebuilding or modifying an
official ISO is unnecessary for the documented R730 case and would weaken the
installation's provenance.

## Validation

After a successful boot:

```bash
uname -r
journalctl -k -b | grep -Ei 'mce|machine check|hardware error'
sudo ./scripts/r730-pve9-preflight.sh --check
```

Keep a fallback kernel installed until the server has completed multiple cold
boots and a representative workload without new MCE records.
