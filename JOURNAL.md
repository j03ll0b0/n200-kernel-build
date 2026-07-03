# N200 Kernel Build - Project Journal

## Project Goal
Build a custom kernel for OnePlus Nord N200 (dre/DE2117) running **LineageOS 23.2** (Android 14) with WireGuard, BBR, LTO/ThinLTO/CFI, and eventually root (KSU-Next or ReSukiSU).

## Key Facts
- **Device**: OnePlus Nord N200 5G (codename `dre`, DE2117)
- **SoC**: SM4350 (Snapdragon 480) — platform codename "holi"
- **ROM**: LineageOS 23.2 (Android 14)
- **Kernel**: 5.4.302 (QGKI) — `arch/arm64/configs/vendor/holi-qgki_defconfig`
- **Build VM**: 172.16.17.128 (usuario/1234) — mostly unused now, CI is primary
- **Host**: /Users/usuario/source/n200-kernel-build/
- **GitHub**: https://github.com/j03ll0b0/n200-kernel-build
- **CI**: GitHub Actions workflow in `.github/workflows/build.yml`

## CI Build History (latest = most relevant)

| # | Status | Features | Notes |
|---|--------|----------|-------|
| 22 | ⏳ running | BBR, flash, BT, no modules | Correct approach: kernel-only zip |
| 21 | — | same as #22 | Triggered but superseded |
| 20 | ✅ success | BBR, modules (35 .ko) | Nested zip issue (user flashed wrapper) |
| 19 | ✅ success | Same as #20 but no BBR | |
| 17 | ❌ failure | QCA_CLD_WLAN=y | Staging driver compile error with clang-20 |
| 8 | ✅ success | Stock LOS + BBR, no modules | **Booted** but no WiFi/BT/audio |
| 2 | ✅ success | Kong's kernel repackaged | Flashed correctly (boot_b), kernel hung at logo |

## Current State (Build #8 — the one that booted)

**Works:**
- ✅ Boots to LineageOS
- ✅ Display, touch, fingerprint
- ✅ Vibrator

**Missing:**
- ❌ WiFi (QCA_CLD_WLAN=m — module not built/included)
- ❌ Bluetooth (MSM_BT_POWER=m — module not built/included)
- ❌ Flashlight (LEDS_QPNP_FLASH_V2=y — not in config)
- ❌ Audio (techpack drivers — not built/included)

## Critical Lesson: Modules vs Built-in

**LineageOS official approach:** Vendor modules (.ko) are **pre-built binary blobs extracted from the device**, NOT built from source. The kernel build only produces the `Image` file. The vendor modules on the phone (`/vendor/lib/modules/`) stay untouched.

**Our mistake (builds #19-20):** We built `.ko` files from the kernel's techpack source using clang-20 and bundled them in the flashable zip. These clang-20 compiled modules are incompatible with the stock vendor modules → **black screen / boot failure**.

**The fix:** `do.modules=0` in anykernel.sh, don't include any `.ko` files. The kernel must be ABI-compatible with the existing vendor blobs.

## Hardware Drivers: How to Fix Properly

| Driver | Type | Fix Approach |
|--------|------|-------------|
| **WiFi** (QCA_CLD_WLAN) | Module (=m) | Must be built as module, compatible with vendor's existing `.ko`. Or: set `=m` in .config, build module, but use **vendor's pre-built module** instead. |
| **BT** (MSM_BT_POWER) | Module (=m) | Same as WiFi — need vendor-compatible module |
| **Flashlight** (LEDS_QPNP_FLASH_V2) | Built-in (=y) | Set in .config, built into kernel Image — no module needed |
| **Audio** (techpack) | Module (=m) | Most complex. Uses `holiauto.conf` env vars, not standard Kconfig. Vendor modules from LOS should work if kernel ABI is compatible. |

**The real solution for modules:** Either:
A) Match the stock LOS kernel config exactly (same ABI) → vendor modules work
B) Extract the vendor `.ko` files from the phone and sign/repackage them
C) Use the same toolchain as LOS (Android NDK r30 beta1, not clang-20 from apt)

## What's in the Repo

| File | Purpose |
|------|---------|
| `.github/workflows/build.yml` | CI workflow: clones Kong's LOS kernel, builds with clang-20, packages AnyKernel3 |
| `build.sh` | Local build script (same as CI but runs on VM) |
| `anykernel.sh` | AnyKernel3 script: dump_boot/write_boot, BLOCK=/dev/block/by-name/boot, IS_SLOT_DEVICE=1 |
| `JOURNAL.md` | This file |
| `SOUL.md` | Older state document (from initial OOS-based build) |

## CI Workflow Details

- **Kernel source**: KongXing0819/android_kernel_oneplus_sm4350:lineage-23.2-new
- **Defconfig**: `vendor/holi-qgki_defconfig`
- **Toolchain**: clang-20, lld-20, llvm-20 (from apt)
- **Extra configs**: BBR, TMPFS_XATTR, TCP_MD5SIG, WireGuard, LEDS_QPNP_FLASH_V2, MSM_BT_POWER, MSM_RDBG, SECTION_MISMATCH_WARN_ONLY=y
- **Packaging**: AnyKernel3 (clone from osm0sis/AnyKernel3), kernel Image + anykernel.sh only
- **Artifact**: GitHub Actions artifact (nested zip — extract inner zip before flashing)

## Flashable Zips in ~/Downloads/

| File | Build | Size | Notes |
|------|-------|------|-------|
| `n200-los23-stock-bbr-*.zip` | #22 (latest) | ~20MB | Kernel only, no modules — **try this first** |
| `n200-kernel-zip (2).zip` | #20 | 121MB | GitHub wrapper — contains `n200-los23-stock-bbr-*.zip` inside + modules |
| `n200-custom-20260703-0745.zip` | OOS build | 21MB | Old OOS-based kernel, bootlooped |
| `AnyKernel3-Resukisu-dre-LOS23.2-latest.zip` | Kong's kernel | 21MB | LOS+ReSukiSU, hung at boot logo |

## Next Steps (in order)

1. ✅ **Flash build #22** — kernel-only with BBR/flash/BT config, no modules, no systemless
2. ⬜ If WiFi/BT/audio still broken → extract vendor modules from phone, compare ABI
3. ⬜ Add root — KSU-Next with **tracepoint hooks** (CONFIG_KSU_TRACEPOINT_HOOK=y, not manual hooks)
4. ⬜ If tracepoint hooks work, add ReSukiSU or KSU-Next permanently

## Useful Commands

```bash
# Trigger CI build
gh workflow run "Build N200 Kernel (Stock LOS 23.2 baseline)" \
  --repo j03ll0b0/n200-kernel-build --ref main \
  -f enable_ksu=false -f enable_bbr=true

# Download CI artifact
gh run download <run-id> --repo j03ll0b0/n200-kernel-build --dir /tmp/out

# Extract inner zip from GitHub artifact
unzip -o n200-kernel-zip.zip && ls *.zip  # then flash the inner one

# Build locally on VM
sshpass -p 1234 ssh usuario@172.16.17.128 'bash ~/build_kernel_full.sh'
```

## Three-Way Comparison (TL;DR)

| Project | Base | Root | Freshness | Verdict |
|---------|------|------|-----------|---------|
| **GarryStraitYT** | LOS 23.2 | SukiSU | 5mo old | Bootlooped, 392 commits ahead |
| **KongXing0819** | LOS 23.2 | ReSukiSU | 1 week old | Hung at logo, 6 commits ahead |
| **Our repo** | LOS 23.2 (CI) | None yet | Latest | Kernel boots, missing WiFi/BT/audio |