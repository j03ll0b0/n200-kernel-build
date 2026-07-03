# N200 Kernel Build — Context & State

## Project: OnePlus Nord N200 (DE2117 / dre / SM4350) Custom Kernel

**Goal:** Build a custom kernel matching the running phone's exact config and toolchain (clang-20 LTO/ThinLTO/PGO/CFI), adding KSU-Next root, BBR, TMPFS_XATTR. Package into AnyKernel3 flashable ZIP.

**Kernel Source:** OnePlus OSS `oneplus/SM4350_R_11.0` branch (5.4.300-qgki)
**Device:** OnePlus Nord N200 5G (codename `dre`)
**Build VM:** 172.16.17.128 (usuario/1234, sudo) — 90GB /build drive
**Host Project:** /Users/usuario/source/n200-kernel-build/
**VM Build Dir:** /build/n200_kernel/
**VM Clang-20:** /usr/lib/llvm-20/bin/clang (version 20.1.2)
**VM LLD-20:** /usr/lib/llvm-20/bin/ld.lld (version 20.1.2)

## Build Status: COMPLETED ✓

**Kernel built:** 2026-07-01
**Image.gz:** 18MB compressed (39MB uncompressed)
**Flashable ZIP:** /Users/usuario/source/n200-kernel-build/n200-ksu-next-full-20260701-0102.zip (21MB)

### What's in the kernel

| Feature | Details |
|---------|---------|
| **Base config** | Extracted from running phone (5,368 entries) |
| **Compiler** | clang-20.1.2 (matching phone's clang 20.0.0) |
| **Linker** | LLD 20.1.2 |
| **Optimization** | LTO + ThinLTO + CFI_CLANG + CFI_SHADOW |
| **Security** | SHADOW_CALL_STACK, SELinux, SECCOMP, STACKPROTECTOR_STRONG |
| **KSU-Next** | v3.2.0-legacy (CONFIG_KSU=y, kprobes hook) |
| **WireGuard** | Built-in (CONFIG_WIREGUARD=y, already in stock) |
| **BBR** | CONFIG_TCP_CONG_BBR=y |
| **TMPFS_XATTR** | CONFIG_TMPFS_XATTR=y |
| **TCP_MD5SIG** | CONFIG_TCP_MD5SIG=y |
| **COMPAT_VDSO** | y (32-bit ARM VDSO support, fixed by patching VDSO32 Makefile) |
| **RELR** | y (RELR relocation packing) |

### Phone Config Reference
- /Users/usuario/source/n200-kernel-build/phone_running_config — exact .config from running phone

## Known Source Fixes Applied

These are OnePlus OSS branch bugs that required patching:

1. **drivers/clk/clk.c** — Removed `list_rate_vdd_level` references (guarded by CONFIG_COMMON_CLK_QCOM_DEBUG which is off)
2. **scripts/gcc-wrapper.py** — Replaced with pass-through (Python 2 wrapper, not needed for clang)
3. **arch/arm64/kernel/vdso32/Makefile** — Changed `-no-integrated-as` to `-integrated-as`, `-fuse-ld=bfd` to `-fuse-ld=lld`
4. **techpack/display/msm/dsi/dsi_panel.c** — Commented out dead include `oplus_op_def.h`
5. **techpack/display/msm/dsi/dsi_panel.c** — Fixed `MSM_BOOT_MODE__FACTORY` → `MSM_BOOT_MODE_FACTORY` (double underscore)
6. **techpack/oneplus/include/linux/oem/boot_mode.h** — Added `MSM_BOOT_MODE_WLAN` to enum
7. **techpack/oneplus/input/oplus_touchscreen/ilitek/ilitek7807s/ili7807s.h** — Added `#include "../../touchpanel_common.h"` with gesture type compat defines
8. **techpack/oneplus/input/oplus_touchscreen/ilitek/ilitek7807s/ili7807s_qcom.c** — Fixed `panel_data->TP_FW` → `panel_data->tp_fw`
9. **techpack/oneplus/input/oplus_touchscreen/ilitek/ilitek_common.c** — Fixed `TX_NUM/RX_NUM/TP_FW/DEV_TP_FW` → lowercase
10. **Config override** — Set `CONFIG_OPLUS_HOLI_CHARGER=y` and `# CONFIG_DRM_MSM is not set` (techpack display provides its own MSM DRM)

## Config Tweaks from Stock Phone

- Added `CONFIG_KSU=y`, `CONFIG_TCP_CONG_BBR=y`, `CONFIG_TMPFS_XATTR=y`, `CONFIG_TCP_MD5SIG=y`
- Enabled `CONFIG_OPLUS_HOLI_CHARGER=y` (for correct charger ic include path)
- Disabled `CONFIG_DRM_MSM` (techpack display provides its own via `holidisp.conf`)

## How to Rebuild

1. SSH to VM: `sshpass -p 1234 ssh usuario@172.16.17.128`
2. Build: `bash ~/build_kernel_full.sh 2>&1 | tee ~/build_output.log`
3. Package: `bash ~/make_anykernel_full.sh`
4. Pull ZIP: `sshpass -p 1234 scp usuario@172.16.17.128:~/n200-ksu-next-full-*.zip ./`

## Key Files

- /Users/usuario/source/n200-kernel-build/phone_running_config — phone's exact config
- /Users/usuario/source/n200-kernel-build/kernel_build/build_kernel_full.sh — incremental build script (clang-20)
- /Users/usuario/source/n200-kernel-build/kernel_build/make_anykernel_full.sh — AnyKernel3 packager
- /Users/usuario/source/n200-kernel-build/boot_a.img — stock boot image (for reference)
- /Users/usuario/source/n200-kernel-build/n200-ksu-next-full-20260701-0102.zip — flashable ZIP