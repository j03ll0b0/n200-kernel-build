# N200 Kernel Build - Project Journal

## Project Goal
Build a custom kernel for OnePlus Nord N200 (dre/DE2117) running **LineageOS 23.2** (Android 14) based on the LineageOS kernel source, with KSU-Next + SukiSU features ported from GarryStraitYT.

## Key Facts
- **Device**: OnePlus Nord N200 5G (codename `dre`, DE2117)
- **SoC**: SM4350 (Snapdragon 480)
- **ROM**: LineageOS 23.2 (Android 14)
- **Kernel**: 5.4.302 (QGKI)
- **Build VM**: 172.16.17.128 (usuario/1234)
- **Host**: /Users/usuario/source/n200-kernel-build/
- **GitHub**: https://github.com/j03ll0b0/n200-kernel-build

## 🔍 Three-Way Comparison (Last updated: 2026-07-03)

### 1️⃣ GarryStraitYT/android_kernel_oneplus_sm4350
- **Branch**: `5.4.302-lineageos23.x`
- **Forked from**: LineageOS/android_kernel_oneplus_sm4350:lineage-23.2
- **Ahead of LOS**: 392 commits (large divergence)
- **Root**: SukiSU (integrated directly into tree)
- **Age**: ~5 months old (last commit Feb 2, 2026)
- **Has CI**: ❌ No GitHub Actions workflow
- **Build method**: Uses Android.mk + OplusKernelEnvConfig.mk (OPlus build system)
- **Pros**: SukiSU is directly in tree, proven custom kernel
- **Cons**: 392 commits makes diff analysis hard, older, no CI

### 2️⃣ KongXing0819/android_kernel_oneplus_sm4350
- **Branch**: `lineage-23.2-new` (also has `lineage-23.2`)
- **Forked from**: LineageOS/android_kernel_oneplus_sm4350:lineage-23.2
- **Ahead of LOS**: Only 6 commits (minimal changes!)
- **Root**: ReSukiSU (via `ksu.sh` -> `curl https://github.com/ReSukiSU/ReSukiSU/main/kernel/setup.sh | bash`)
- **Age**: ~1 week old (last commit Jun 27, 2026)
- **Has CI**: ✅ GitHub Actions "Build Android Kernel with NDK" (proven, 12+ successful runs)
- **Build method**: Android NDK r30 beta1 (LLVM/clang) + `build/.config` + `make O=build LLVM=1`
- **Key features in `build/.config`**: LTO, ThinLTO, CFI, WireGuard, Shadow Call Stack, KSU hooks (manual)
- **Missing features**: BBR (CUBIC only), TMPFS_XATTR disabled, TCP_MD5SIG disabled, KSU disabled (n)
- **Pros**: Most recent, minimal changes from stock LOS, proven CI builds, ReSukiSU integration
- **Cons**: Missing our extra features (BBR, TMPFS_XATTR, etc.)

### 3️⃣ Our Repo (j03ll0b0/n200-kernel-build) — CURRENT RECIPE
- **Kernel base**: OnePlus OSS (`oneplus/SM4350_R_11.0`) — OOS 11 base
- **Root**: KSU-Next v3.2.0-legacy
- **Features**: BBR, TMPFS_XATTR, TCP_MD5SIG, LTO/ThinLTO/CFI, SCS, COMPAT_VDSO
- **Toolchain**: clang-20
- **Has CI**: ✅ GitHub Actions (simple build.yml + detailed build-n200.yml)
- **Pros**: Has all features we want
- **Cons**: OOS kernel base may not match LineageOS 23.2 — **untested** (user couldn't flash yet)

## ✅ Unified Recipe (Target)

**Base**: KongXing0819's `lineage-23.2-new` (most recent LOS 23.2, proven CI)
**Root**: ReSukiSU (via ksu.sh from KongXing0819's repo)
**Extra features** (currently missing from Kong's config):
  - CONFIG_TCP_CONG_BBR=y (replace CUBIC)
  - CONFIG_TMPFS_XATTR=y
  - CONFIG_TCP_MD5SIG=y
  - CONFIG_KSU=y (enable ReSukiSU)
**Build system**: `build.sh` (runs locally or via CI)
**AnyKernel3**: Our own `anykernel.sh` (updated to proper format)
**Packaging**: make_anykernel_fixed.sh style

## What's Good from Each Project

### From KongXing0819:
- ✅ LOS 23.2 kernel base (correct for phone's ROM)
- ✅ ksu.sh integration with ReSukiSU (latest root)
- ✅ build/.config preconfigured with LTO, ThinLTO, CFI, WireGuard, SCS
- ✅ GitHub Actions workflow (proven)
- ✅ Clang/LLVM toolchain (NDK r30)

### From GarryStraitYT:
- ✅ SukiSU integration approach
- ✅ Kernel concept (already on LOS 23.2)
- ✅ Our build scripts (build_kernel_full.sh, make_anykernel_fixed.sh)

### From Our Repo:
- ✅ Extra features config (BBR, TMPFS_XATTR, TCP_MD5SIG)
- ✅ Proper anykernel.sh with device checks
- ✅ clang-20 toolchain config

## Decision
**Use KongXing0819's repo as the kernel base** → add our missing features → build with our build.sh → package with proper AnyKernel3.

## Status
- [x] Found GarryStraitYT repo (branch: 5.4.302-lineageos23.x)
- [x] Found LineageOS 23.2 kernel source
- [x] Identified: Garry's kernel bootloops (heavily diverged, 392 commits ahead of LOS); our kernel is untested
- [x] Found KongXing0819's repo (LOS 23.2 + ReSukiSU, proven CI)
- [x] Downloaded latest KernelSU artifact from Kong's CI
- [x] Packaged Kong's kernel as AnyKernel3 flashable ZIP
- [x] Updated build.sh with unified recipe
- [x] Updated anykernel.sh with proper format
- [ ] Push updated repo and test CI
- [ ] Flash and test on device

## Commands
```bash
# Clone kernel
git clone --depth=1 --branch lineage-23.2-new \
  https://github.com/KongXing0819/android_kernel_oneplus_sm4350.git

# Run our build
cd /Users/usuario/source/n200-kernel-build
bash build.sh
```