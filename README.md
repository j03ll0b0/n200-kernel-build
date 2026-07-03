# OnePlus Nord N200 (dre/DE2117) Kernel with KernelSU-Next

Custom kernel for OnePlus Nord N200 5G (SM4350/Snapdragon 480) built with clang-20, LTO/ThinLTO/CFI, featuring KernelSU-Next v3.2.0-legacy root, WireGuard, BBR, and more.

## Features

- **KernelSU-Next v3.2.0-legacy** - Kernel-level root solution (KSU compatible, kernel 5.4 support)
- **clang-20 toolchain** with LTO, ThinLTO, CFI, Shadow Call Stack
- **WireGuard** kernel module support
- **BBR + ECN** TCP congestion control
- **TMPFS_XATTR** extended attributes support
- **9 critical source patches** applied for build compatibility
- **AnyKernel3** flashable ZIP for easy installation

## Device Support

| Device | Codename | SoC | Android |
|--------|----------|-----|---------|
| OnePlus Nord N200 5G | dre / DE2117 | SM4350 (SD 480) | 11 (OOS 11) |

## ⚠️ SusFS Note

**SusFS is NOT included in this build.** The SusFS project provides GKI-compatible branches starting from `gki-android12-5.10`. There is no `gki-android11-5.4` branch, so SusFS cannot be properly integrated for Android 11 / kernel 5.4. The `kernel-5.4` branch exists but is not Android 11 GKI compatible.

This is a deliberate choice - we use KernelSU-Next v3.2.0-legacy which provides solid root functionality for kernel 5.4 without requiring SusFS.

## Building

### GitHub Actions (Recommended)

1. Fork this repository
2. Go to **Actions** → **Build and Release OnePlus N200 Kernel**
3. Click **Run workflow**
4. Configure:
   - `make_release`: Create GitHub Release with flashable ZIP
   - `ksu_version`: KernelSU-Next version (default: v3.2.0-legacy)
   - `optimize_level`: O2 or O3
   - `clean_build`: Disable ccache
5. Download artifact from workflow run or Release

### Local Build (VM/Server)

Requires Ubuntu 22.04+ with 16GB+ RAM:

```bash
git clone https://github.com/YOUR_USERNAME/n200-kernel-build.git
cd n200-kernel-build
./build.sh
```

## Installation

### Via Kernel Flasher (Recommended)

1. Download latest `n200-ksu-next-*.zip` from Releases
2. Install [Kernel Flasher](https://github.com/fatalcoder524/KernelFlasher) on device
3. Open Kernel Flasher → Flash → Select ZIP → Flash to inactive slot
4. Reboot

### Via Recovery Sideload

```bash
adb reboot recovery
# In recovery: Apply update → Apply from ADB
adb sideload n200-ksu-next-*.zip
```

### Via Fastboot (boot.img only)

```bash
adb reboot bootloader
fastboot flash boot_a boot.img
fastboot reboot
```

## Post-Install

1. Install [KernelSU Manager](https://github.com/KernelSU-Next/KernelSU-Next/releases) (v33129+)
2. Grant root permissions in manager
3. Verify: `su -v` should show KernelSU version

## Source Patches Applied

| # | File | Fix |
|---|------|-----|
| 1 | `arch/arm64/kernel/vdso32/Makefile` | clang-20 integrated-as + LLD |
| 2 | `scripts/gcc-wrapper.py` | Python3 pass-through wrapper |
| 3 | `drivers/clk/clk.c` | Remove vdd_level references |
| 4 | `ili7807s.h` | Touchpanel gesture compat defines |
| 5 | `ili7807s_qcom.c` | TP_FW → tp_fw fix |
| 6 | `ilitek_common.c` | Struct member names (TX_NUM→tx_num, etc) |
| 7 | `dsi_panel.c` | Comment oplus_op_def.h include |
| 8 | `dsi_panel.c` | Fix MSM_BOOT_MODE__* enums |
| 9 | `sm4350_defconfig` | Enable CONFIG_OPLUS_HOLI_CHARGER |

## Credits & Attribution

This project is heavily based on and inspired by the excellent work of:

- **[Bouteillepleine/SukiSu_Ultra_Oneplus-](https://github.com/Bouteillepleine/SukiSu_Ultra_Oneplus-)** - Build workflow, device config format, manifest structure, and patching approach. Their GitHub Actions workflow served as the primary template for this project.

- **[KernelSU-Next](https://github.com/KernelSU-Next/KernelSU-Next)** - Root solution (v3.2.0-legacy for kernel 5.4)

- **[OnePlusOSS](https://github.com/OnePlusOSS)** - Kernel source: `android_kernel_oneplus_sm4350` and techpack

- **[osm0sis/AnyKernel3](https://github.com/osm0sis/AnyKernel3)** - Flashable ZIP framework

- **[simonpunk/susfs4ksu](https://gitlab.com/simonpunk/susfs4ksu)** - SusFS reference (not used for android11-5.4)

## License

GPL-2.0 (kernel) / MIT (scripts)

---

⚠️ **Warning**: Flashing custom kernels may void warranty and can brick your device. Always backup boot/init_boot/vendor_boot partitions before flashing. Use at your own risk.