#!/bin/bash
set -euo pipefail

# Local build script for OnePlus N200 kernel
# Run on Ubuntu 22.04+ VM/server with 16GB+ RAM

echo "=== OnePlus N200 Kernel Builder ==="
echo "Device: OnePlus Nord N200 (dre/DE2117)"
echo "SoC: SM4350 (Snapdragon 480)"
echo "Kernel: 5.4, Android 11 (OOS 11)"
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

# Initialize repo with OnePlus kernel source
echo "=== Syncing kernel source ==="
repo init -u https://github.com/OnePlusOSS/android_kernel_oneplus_sm4350 -b oneplus/SM4350_R_11.0 --depth=1
repo sync -j$(nproc) -c --no-tags --no-clone-bundle --optimized-fetch --prune

# Sync techpack (modules + dtb)
echo "=== Syncing techpack ==="
git clone --depth=1 --branch oneplus/SM4350_R_11.0 https://github.com/OnePlusOSS/android_kernel_modules_and_devicetree_oneplus_sm4350 techpack

# Setup AnyKernel3
echo "=== Setting up AnyKernel3 ==="
git clone --depth=1 --branch gki-2.0 https://github.com/osm0sis/AnyKernel3

# Apply patches
echo "=== Applying patches ==="
cd kernel-5.4
bash ../../scripts/apply_patches.sh
cd ..

# Setup KernelSU-Next (v3.2.0-legacy for kernel 5.4)
echo "=== Setting up KernelSU-Next ==="
cd kernel-5.4
git clone --depth=1 --branch v3.2.0-legacy https://github.com/KernelSU-Next/KernelSU-Next KernelSU-Next
ln -sf ../KernelSU-Next/kernel drivers/kernelsu
cd ..

# Configure kernel
echo "=== Configuring kernel ==="
cd kernel-5.4
export ARCH=arm64
export SUBARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_ARM32=arm-linux-gnueabihf-

# Use prebuilt clang from CodeLinaro (matching manifest)
CLANG_PATH="../kernel_platform/prebuilts-master/clang/host/linux-x86/clang-r416183c/bin"
if [ ! -d "$CLANG_PATH" ]; then
    echo "Prebuilt clang not found, using system clang"
    export CC=clang
    export LD=ld.lld
    export AR=llvm-ar
    export NM=llvm-nm
    export OBJCOPY=llvm-objcopy
    export OBJDUMP=llvm-objdump
    export STRIP=llvm-strip
else
    export PATH="$CLANG_PATH:$PATH"
    export CC=clang
    export LD=ld.lld
    export AR=llvm-ar
    export NM=llvm-nm
    export OBJCOPY=llvm-objcopy
    export OBJDUMP=llvm-objdump
    export STRIP=llvm-strip
fi

make O=out sm4350_defconfig

# Enable our features
./scripts/config --file out/.config \
  -e CONFIG_KSU \
  -e CONFIG_TCP_CONG_BBR \
  -e CONFIG_TMPFS_XATTR \
  -e CONFIG_TCP_MD5SIG \
  -e CONFIG_OPLUS_HOLI_CHARGER \
  -d CONFIG_DRM_MSM

# LTO/ThinLTO/CFI
./scripts/config --file out/.config \
  -e CONFIG_LTO \
  -e CONFIG_THINLTO \
  -e CONFIG_CFI_CLANG \
  -e CONFIG_SHADOW_CALL_STACK \
  -e CONFIG_COMPAT_VDSO

make O=out olddefconfig

# Build kernel
echo "=== Building kernel ==="
BUILD_START=$(date +%s)
make O=out -j$(nproc) 2>&1 | tee build.log
BUILD_END=$(date +%s)

echo "Build time: $((BUILD_END - BUILD_START)) seconds"

# Package AnyKernel3
echo "=== Packaging AnyKernel3 ZIP ==="
cd ../AnyKernel3
cp ../kernel-5.4/out/arch/arm64/boot/Image .
cp ../../anykernel.sh .
zip -r9 ../n200-ksu-next-$(date +%Y%m%d-%H%M).zip . -x ".git/*" "*.md" "README*" "LICENSE"

echo ""
echo "=== Build complete ==="
echo "ZIP: ../n200-ksu-next-*.zip"
echo "Flash via Kernel Flasher or recovery sideload"