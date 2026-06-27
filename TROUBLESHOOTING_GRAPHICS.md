# Graphics troubleshooting — omen01

Hardware: Intel HD Graphics 630 (i915) + NVIDIA GeForce GTX 1050 Ti Mobile (Optimus laptop).

Deploy command: `nix run github:serokell/deploy-rs -- .#omen01`

---

## Root cause (confirmed)

`hardware.nvidia` alone does **not** install or load the nvidia kernel module. NixOS only builds it when `"nvidia"` appears in `services.xserver.videoDrivers`.

Evaluating the flake before the fix:

```
nix eval .#nixosConfigurations.omen01.config.services.xserver.videoDrivers --json
```

Result: `["modesetting","fbdev"]` — no `"nvidia"`.

That explains all three symptoms below:

| Symptom | Why |
|---------|-----|
| `modinfo nvidia` → not found | Module was never added to `/run/current-system/kernel-modules` |
| GTX 1050 Ti still on `nouveau` | No proprietary driver to bind; nouveau fills the gap |
| `grep nouveau /run/current-system` only hits docs | No nvidia modprobe config generated |

**Fix applied in `hosts/omen01/default.nix`:**

```nix
services.xserver.videoDrivers = [ "modesetting" "nvidia" ];

hardware.nvidia = {
  modesetting.enable = true;
  open = false;
  package = config.boot.kernelPackages.nvidiaPackages.stable;
  prime = {
    offload = {
      enable = true;
      enableOffloadCmd = true;
    };
    intelBusId = "PCI:0:2:0";
    nvidiaBusId = "PCI:1:0:0";
  };
};
```

- `modesetting` — Intel iGPU (required for Optimus offload; do not use `"intel"` here on modern NixOS).
- `nvidia` — builds and loads the proprietary kernel module.
- `prime.offload` — laptop renders on Intel by default; discrete GPU on demand via `nvidia-offload`.
- `open = false` — GTX 1050 Ti (Pascal) needs proprietary modules, not the open kernel modules (Turing+ only).

After deploy: **reboot required** (kernel module change).

---

## Symptom: `nixos-option hardware.nvidia.package` fails

```
error: attribute 'omen01' missing
at «string»:1:1:
     1| (builtins.getFlake "/etc/nixos").nixosConfigurations."omen01"
```

**Not a driver bug.** `nixos-option` reads `/etc/nixos` on the machine. deploy-rs activates the system profile but does **not** replace `/etc/nixos` with this flake. The path still points at an old or empty flake without `nixosConfigurations.omen01`.

**Inspect the running system instead:**

```bash
# What generation is actually active?
readlink /run/current-system

# Was nvidia module built into this generation?
find /run/current-system -path '*/kernel/drivers/video/nvidia.ko*' 2>/dev/null
ls /run/current-system/kernel-modules/lib/modules/$(uname -r)/kernel/drivers/video/ 2>/dev/null

# What videoDrivers did this generation get?
grep -r videoDrivers /run/current-system/etc/nixos 2>/dev/null   # often empty with deploy-rs
```

**Inspect from your dev machine (authoritative — matches what deploy sends):**

```bash
nix eval .#nixosConfigurations.omen01.config.services.xserver.videoDrivers --json
nix eval .#nixosConfigurations.omen01.config.hardware.nvidia.package.name --raw
```

**Optional:** symlink or copy the flake to `/etc/nixos` on omen01 so `nixos-option` works locally:

```bash
sudo ln -sfn /path/to/server-setup /etc/nixos
nixos-option -F /etc/nixos#omen01 hardware.nvidia.package
```

---

## Symptom: `modinfo nvidia` → Module nvidia not found

Expected **before** adding `"nvidia"` to `videoDrivers`. After deploy + reboot, expect:

```bash
modinfo nvidia | head -5
# filename: /run/booted-system/kernel-modules/lib/modules/.../kernel/drivers/video/nvidia.ko.xz
```

If still missing after deploy + reboot:

1. Confirm deploy succeeded (no build errors in deploy-rs output).
2. Confirm you rebooted into the new generation (`/run/current-system` mtime / generation number).
3. Check `dmesg | grep -i nvidia` for module load failures (version mismatch, secure boot, etc.).

---

## Symptom: `lspci` shows nouveau on the GTX 1050 Ti

```
01:00.0 VGA ... GeForce GTX 1050 Ti Mobile
	Kernel driver in use: nouveau
```

Expected when the proprietary module is absent. After fix + reboot, expect either:

- `Kernel driver in use: nvidia` (if the GPU is active), or
- No driver in use (normal for Optimus offload — Intel handles display, NVIDIA idle until offload).

Check Intel side still on i915:

```bash
lspci -nnk | grep -A3 '00:02.0'
```

Post-fix verification:

```bash
nvidia-smi                    # should work after reboot
nvidia-offload vulkaninfo     # if using prime offload + enableOffloadCmd
cat /proc/driver/nvidia/version
```

---

## Symptom: `grep -R nouveau /run/current-system` only finds docs

That is normal — the grep hit list being only `options.html` means no nvidia blacklist modprobe snippet was generated, which is consistent with the nvidia module never being enabled. After the fix you should see modprobe config under:

```bash
ls /run/current-system/etc/modprobe.d/
grep -r nouveau /run/current-system/etc/modprobe.d/
```

---

## Deploy checklist

1. Commit/push config with `videoDrivers` fix.
2. Deploy: `nix run github:serokell/deploy-rs -- .#omen01`
3. Reboot omen01.
4. Verify:

```bash
modinfo nvidia | head -3
nvidia-smi
lspci -nnk | grep -A3 -E '(VGA|3D)'
```

---

## If it still fails after reboot

| Check | Command |
|-------|---------|
| Secure Boot blocking unsigned nvidia module | `mokutil --sb-state` — disable Secure Boot or enroll MOK |
| Kernel / driver version mismatch | `cat /proc/driver/nvidia/version` vs `nvidia-smi` — usually fixed by reboot |
| Wrong GPU selected in BIOS | Set to hybrid / Optimus, not discrete-only without proper driver |
| Try beta driver if stable fails on latest kernel | `package = config.boot.kernelPackages.nvidiaPackages.beta;` |
| Force sync instead of offload (uses more power) | `hardware.nvidia.prime.sync.enable = true;` and remove `offload.enable` |

---

## Reference: commands already run

<details>
<summary>Pre-fix command output</summary>

`nixos-option hardware.nvidia.package`

```
error: attribute 'omen01' missing
at «string»:1:1:
     1| (builtins.getFlake "/etc/nixos").nixosConfigurations."omen01"
```

`grep -R nouveau /run/current-system` — only documentation hits in `options.html`.

`modinfo nvidia` — `ERROR: Module nvidia not found.`

`lspci -nnk | grep -A3 -E '(VGA|3D)'`

```
00:02.0 VGA ... Intel HD Graphics 630
	Kernel driver in use: i915
01:00.0 VGA ... GeForce GTX 1050 Ti Mobile
	Kernel driver in use: nouveau
```

</details>
