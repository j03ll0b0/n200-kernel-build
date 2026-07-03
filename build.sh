#!/bin/bash
set -euo pipefail

# N200 Kernel Builder — Unified Recipe v2
# Device: OnePlus Nord N200 (dre/DE2117)
# SoC: SM4350 (Snapdragon 480)
# Kernel: 5.4.302, LineageOS 23.2 (Android 14)
# Root: ReSukiSU (via KongXing0819's ksu.sh)

echo "=== N200 Kernel Builder (Unified Recipe v2) ==="
echo "Device: OnePlus Nord N200 (dre/DE2117)"
echo "SoC: SM4350 (Snapdragon 480)"
echo "Kernel: LineageOS 23.2 + ReSukiSU"
echo ""

# Install dependencies
echo "=== Installing dependencies ==="
sudo apt-get -o Acquire::Retries=3 update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  repo git-core gnupg flex bison gperf build-essential \
  zip curl zlib1g-dev gcc-multilib g++-multilib libc6-dev-i386 \
  lib32ncurses5-dev x11proto-core-dev libx11-dev lib32z1-dev \
  libgl1-mesa-dev libxml2-utils xsltproc unzip fontconfig \
  libncurses5 libncurses5-dev python3 python3-pip python3-venv \
  bc cpio rsync ccache libssl-dev ninja-build libelf-dev \
  aarch64-linux-gnu-gcc arm-linux-gnueabihf-gcc

# Create build directory
mkdir -p build && cd build

# === Step 1: Clone kernel source (KongXing0819 — LOS 23.2 + ReSukiSU) ===
echo "=== Cloning kernel source ==="
if [ ! -d "kernel-5.4" ]; then
  git clone --depth=1 --branch lineage-23.2-new \
    https://github.com/KongXing0819/android_kernel_oneplus_sm4350.git kernel-5.4
fi

cd kernel-5.4

# === Step 2: Integrate ReSukiSU ===
echo "=== Integrating ReSukiSU ==="
if [ -f ksu.sh ]; then
  chmod +x ksu.sh
  ./ksu.sh
else
  # Direct integration as fallback
  curl -LSs "https://raw.githubusercontent.com/ReSukiSU/ReSukiSU/main/kernel/setup.sh" | bash
fi

# === Step 3: Apply clang-20 compatibility patches ===
echo "=== Applying clang-20 compatibility ==="

# Fix VDSO32 Makefile for clang-20
if [ -f arch/arm64/kernel/vdso32/Makefile ]; then
  sed -i 's/-no-integrated-as/-integrated-as/g' arch/arm64/kernel/vdso32/Makefile 2>/dev/null || true
  sed -i 's/-fuse-ld=bfd/-fuse-ld=lld/g' arch/arm64/kernel/vdso32/Makefile 2>/dev/null || true
fi

# === Step 4: Configure kernel ===
echo "=== Configuring kernel ==="
export ARCH=arm64
export SUBARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_ARM32=arm-linux-gnueabihf-

# Use KongXing0819's prebuilt config (has WireGuard, LTO, ThinLTO, CFI, SCS)
cp build/.config .config 2>/dev/null || cp out/.config .config 2>/dev/null || true

# If no existing config, start from defconfig
if [ ! -f .config ]; then
  # QGKI kernel - use fragments
  make O=out defconfig
  for cfg in \
    arch/arm64/configs/vendor/sm4350_QGKI.config \
    arch/arm64/configs/vendor/sm4350.config; do
    if [ -f "$cfg" ]; then
      scripts/kconfig/merge_config.sh -O out out/.config "$cfg" 2>/dev/null || true
    fi
  done
  cp out/.config .config
fi

# === Step 5: Enable our extra features ===
echo "=== Enabling extra features ==="
scripts/config \
  -e CONFIG_TCP_CONG_ADVANCED \
  -e CONFIG_TCP_CONG_BBR \
  -e CONFIG_TMPFS_XATTR \
  -e CONFIG_TCP_MD5SIG \
  -d CONFIG_TCP_CONG_CUBIC

# Ensure KSU is enabled (ReSukiSU needs this)
scripts/config -e CONFIG_KSU

# Ensure LTO/ThinLTO/CFI are enabled
scripts/config \
  -e CONFIG_LTO \
  -e CONFIG_THINLTO \
  -e CONFIG_LTO_CLANG \
  -e CONFIG_CFI_CLANG \
  -e CONFIG_CFI_CLANG_SHADOW \
  -e CONFIG_SHADOW_CALL_STACK \
  -d CONFIG_LTO_NONE

make O=out olddefconfig

echo "=== Feature check ==="
grep -E 'CONFIG_KSU=|CONFIG_TCP_CONG_BBR=|CONFIG_WIREGUARD=|CONFIG_TMPFS_XATTR=|CONFIG_LTO=|CONFIG_THINLTO=|CONFIG_CFI_CLANG=|CONFIG_SHADOW_CALL_STACK=' out/.config

# === Step 6: Build kernel ===
echo "=== Building kernel ==="
BUILD_START=$(date +%s)

# Use system clang (clang-20 if available, otherwise system default)
CC_BIN=$(which clang-20 2>/dev/null || which clang 2>/dev/null || echo "clang")

make O=out -j$(nproc) \
  CC="$CC_BIN" \
  LD=$(which ld.lld 2>/dev/null || echo "ld.lld") \
  AR=$(which llvm-ar 2>/dev/null || echo "llvm-ar") \
  NM=$(which llvm-nm 2>/dev/null || echo "llvm-nm") \
  OBJCOPY=$(which llvm-objcopy 2>/dev/null || echo "llvm-objcopy") \
  OBJDUMP=$(which llvm-objdump 2>/dev/null || echo "llvm-objdump") \
  STRIP=$(which llvm-strip 2>/dev/null || echo "llvm-strip") \
  KCFLAGS="-Wno-unused-but-set-variable -Wno-strict-prototypes \
           -Wno-implicit-function-declaration -Wno-implicit-int \
           -Wno-unused-const-variable -Wno-unused-function \
           -Wno-incompatible-function-pointer-types" \
  2>&1 | tee build.log

BUILD_END=$(date +%s)
echo "Build time: $((BUILD_END - BUILD_START)) seconds"

# === Step 7: Package AnyKernel3 ===
echo "=== Packaging AnyKernel3 ZIP ==="

# Find kernel image
if [ -f "out/arch/arm64/boot/Image.gz" ]; then
  KERNEL_IMG="out/arch/arm64/boot/Image.gz"
  KERNEL_NAME="Image.gz"
elif [ -f "out/arch/arm64/boot/Image" ]; then
  KERNEL_IMG="out/arch/arm64/boot/Image"
  KERNEL_NAME="Image"
else
  echo "ERROR: Kernel image not found!"
  exit 1
fi

# Setup AnyKernel3
cd ..
if [ ! -d "AnyKernel3" ]; then
  git clone --depth=1 https://github.com/osm0sis/AnyKernel3
fi
cd AnyKernel3
rm -rf Image Image.gz Image.gz-dtb dtb dtbs kernel anykernel.sh 2>/dev/null || true

# Copy kernel image
cp "../kernel-5.4/$KERNEL_IMG" .

# Write anykernel.sh (working method for OnePlus Nord N200)
cat > anykernel.sh << 'AKEOF'
### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers

### AnyKernel setup
properties() { '
kernel.string=N200 ReSukiSU Kernel | LOS 23.2 | LTO/ThinLTO/CFI | BBR
do.devicecheck=1
do.modules=0
do.systemless=0
do.cleanup=1
do.cleanuponabort=0
device.name1=OnePlusN200
device.name2=dre
device.name3=DE2117
device.name4=DE2115
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; }

### AnyKernel install
boot_attributes() {
set_perm_recursive 0 0 755 644 $RAMDISK/*;
set_perm_recursive 0 0 750 750 $RAMDISK/init* $RAMDISK/sbin;
}

BLOCK=/dev/block/by-name/boot;
IS_SLOT_DEVICE=1;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

. tools/ak3-core.sh;

dump_boot;
write_boot;
AKEOF

# Build ZIP
ZIP_NAME="n200-resukisu-$(date +%Y%m%d-%H%M).zip"
zip -r9 "../$ZIP_NAME" . -x ".git/*" "*.md" "README*" "LICENSE" 2>/dev/null

echo ""
echo "=== Build complete ==="
echo "ZIP: $ZIP_NAME"
echo "Features: LineageOS 23.2 + ReSukiSU + WireGuard + BBR + TMPFS_XATTR + LTO/ThinLTO/CFI + SCS"
echo "Flash via KernelFlasher or recovery sideload"