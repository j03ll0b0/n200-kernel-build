### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers

### AnyKernel setup
properties() { '
kernel.string=N200 Custom Kernel | KSU-Next | LTO/ThinLTO/CFI | BBR
do.devicecheck=1
do.modules=1
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