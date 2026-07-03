#!/bin/bash
set -euo pipefail

cd /build/n200_kernel/kernel-5.4

# 1. VDSO32 Makefile - clang-20 compatibility
sed -i 's/-no-integrated-as//g' arch/arm64/kernel/vdso32/Makefile
sed -i 's/-fuse-ld=bfd/-fuse-ld=lld/g' arch/arm64/kernel/vdso32/Makefile

# 2. gcc-wrapper.py - Python3 pass-through
cat > scripts/gcc-wrapper.py << 'EOF'
#!/usr/bin/env python3
import sys, subprocess
subprocess.run(sys.argv[1:])
EOF
chmod +x scripts/gcc-wrapper.py

# 3. clk.c - remove vdd_level references
sed -i '/list_rate_vdd_level/d' drivers/clk/clk.c

# 4. ili7807s.h - touchpanel compat defines
sed -i '1i#include "../../touchpanel_common.h"' techpack/oneplus/input/oplus_touchscreen/ilitek/ilitek7807s/ili7807s.h
cat >> techpack/oneplus/input/oplus_touchscreen/ilitek/ilitek7807s/ili7807s.h << 'EOF'

#ifndef TOUCHPANEL_COMMON_H
#define TOUCHPANEL_COMMON_H
#define DOU_TAP 2
#define RIGHT2LEFTSWIPT 3
#define LEFT2RIGHTSWIPT 4
#define UP2DOWNSWIPT 5
#define DOWN2UPSWIPT 6
#define M_SWIPT 7
#define W_SWIPT 8
#define HEART_SWIPT 9
#define C_SWIPT 10
#define S_SWIPT 11
#define V_SWIPT 12
#define E_SWIPT 13
#define O_SWIPT 14
#define Z_SWIPT 15
#define TRIANGLE_SWIPT 16
#define BUZZ_SWIPT 17
#endif
EOF

# 5. ili7807s_qcom.c - fix TP_FW -> tp_fw
sed -i 's/panel_data->TP_FW/panel_data->tp_fw/g' techpack/oneplus/input/oplus_touchscreen/ilitek/ilitek7807s/ili7807s_qcom.c

# 6. ilitek_common.c - fix struct member names
sed -i 's/TX_NUM/tx_num/g; s/RX_NUM/rx_num/g; s/TP_FW/tp_fw/g' techpack/oneplus/input/oplus_touchscreen/ilitek/ilitek_common.c

# 7. dsi_panel.c - comment oplus_op_def.h
sed -i 's|#include <../../../oneplus/power/oplus_chg/oplus_op_def.h>|// #include <../../../oneplus/power/oplus_chg/oplus_op_def.h>|' techpack/display/msm/dsi/dsi_panel.c

# 8. dsi_panel.c - fix boot mode enums
sed -i 's/MSM_BOOT_MODE__FACTORY/MSM_BOOT_MODE_FACTORY/g; s/MSM_BOOT_MODE__RF/MSM_BOOT_MODE_RF/g; s/MSM_BOOT_MODE__WLAN/MSM_BOOT_MODE_WLAN/g' techpack/display/msm/dsi/dsi_panel.c

# 9. Enable OPLUS_HOLI_CHARGER
echo 'CONFIG_OPLUS_HOLI_CHARGER=y' >> arch/arm64/configs/sm4350_defconfig

echo "All patches applied successfully"