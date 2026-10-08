#!/usr/bin/env bash

# ============================================================
# Lain GRUB Theme Installer
#
# 功能：
#   1. 安装 Lain GRUB 主题
#   2. 设置 GRUB_THEME
#   3. 设置 GRUB_GFXMODE=1920x1080
#   4. 设置 GRUB_DEFAULT=saved
#   5. 设置 GRUB_SAVEDEFAULT=true
#   6. 自动生成 grub.cfg
#
# 注意：
#   - 本主题目前按照 1920x1080（1K / FHD）设计
#   - GRUB 菜单 Entry 定制由 patch_entries.sh 负责
# ============================================================

set -e
set -o pipefail


# ============================================================
# 颜色
# ============================================================

bgreen="\033[1;32m"
bred="\033[1;31m"
bcyan="\033[1;36m"
ucyan="\033[4;36m"
reset="\033[0m"


# ============================================================
# 路径
# ============================================================

SHPATH="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null
    pwd
)"

GRUB_DEFAULT="/etc/default/grub"
GRUB_THEME_DIR="/boot/grub/themes/lain"
GRUB_THEME_FILE="$GRUB_THEME_DIR/theme.txt"
GRUB_CFG="/boot/grub/grub.cfg"


# ============================================================
# 标题
# ============================================================

echo
echo "============================================================"
echo "              Lain GRUB Theme Installer"
echo "============================================================"
echo


# ============================================================
# 检查主题文件
# ============================================================

if [[ ! -f "$SHPATH/lain/theme.txt" ]]; then

    echo -e "${bred}错误：找不到 Lain GRUB 主题文件。${reset}"
    echo
    echo "应该存在："
    echo "  $SHPATH/lain/theme.txt"
    echo

    exit 1

fi


# ============================================================
# 检查 GRUB 配置
# ============================================================

if [[ ! -f "$GRUB_DEFAULT" ]]; then

    echo -e "${bred}错误：找不到 $GRUB_DEFAULT${reset}"
    echo

    exit 1

fi


# ============================================================
# 1. 安装主题
# ============================================================

echo "===== 1. 安装 Lain GRUB Theme ====="
echo

sudo mkdir -p /boot/grub/themes

sudo cp -r -f \
    "$SHPATH/lain" \
    /boot/grub/themes/

echo "主题已安装："
echo "  $GRUB_THEME_FILE"


# ============================================================
# 2. 设置 GRUB_THEME
# ============================================================

echo
echo "===== 2. 设置 GRUB_THEME ====="

if grep -q '^GRUB_THEME=' "$GRUB_DEFAULT"; then

    sudo sed -i \
        's|^GRUB_THEME=.*|GRUB_THEME="/boot/grub/themes/lain/theme.txt"|' \
        "$GRUB_DEFAULT"

else

    echo 'GRUB_THEME="/boot/grub/themes/lain/theme.txt"' |
        sudo tee -a "$GRUB_DEFAULT" >/dev/null

fi

echo 'GRUB_THEME="/boot/grub/themes/lain/theme.txt"'


# ============================================================
# 3. 设置 GRUB 分辨率
#
# 本主题目前只按照 1920x1080 设计。
# ============================================================

echo
echo "===== 3. 设置 GRUB 分辨率 ====="

if grep -q '^GRUB_GFXMODE=' "$GRUB_DEFAULT"; then

    sudo sed -i \
        's/^GRUB_GFXMODE=.*/GRUB_GFXMODE=1920x1080/' \
        "$GRUB_DEFAULT"

else

    echo 'GRUB_GFXMODE=1920x1080' |
        sudo tee -a "$GRUB_DEFAULT" >/dev/null

fi

echo "GRUB_GFXMODE=1920x1080"


# ============================================================
# 4. Remember Last Boot Entry
# ============================================================

echo
echo "===== 4. Remember Last Boot Entry ====="

if grep -q '^GRUB_DEFAULT=' "$GRUB_DEFAULT"; then

    sudo sed -i \
        's/^GRUB_DEFAULT=.*/GRUB_DEFAULT=saved/' \
        "$GRUB_DEFAULT"

else

    echo 'GRUB_DEFAULT=saved' |
        sudo tee -a "$GRUB_DEFAULT" >/dev/null

fi


if grep -q '^GRUB_SAVEDEFAULT=' "$GRUB_DEFAULT"; then

    sudo sed -i \
        's/^GRUB_SAVEDEFAULT=.*/GRUB_SAVEDEFAULT=true/' \
        "$GRUB_DEFAULT"

elif grep -q '^#GRUB_SAVEDEFAULT=' "$GRUB_DEFAULT"; then

    sudo sed -i \
        's/^#GRUB_SAVEDEFAULT=.*/GRUB_SAVEDEFAULT=true/' \
        "$GRUB_DEFAULT"

else

    echo 'GRUB_SAVEDEFAULT=true' |
        sudo tee -a "$GRUB_DEFAULT" >/dev/null

fi

echo "GRUB_DEFAULT=saved"
echo "GRUB_SAVEDEFAULT=true"


# ============================================================
# 5. 生成 GRUB 配置
# ============================================================

echo
echo "============================================================"
echo "                  生成 GRUB 配置"
echo "============================================================"
echo

if ! command -v grub-mkconfig >/dev/null 2>&1; then

    echo -e "${bred}错误：找不到 grub-mkconfig。${reset}"
    exit 1

fi


sudo grub-mkconfig \
    -o "$GRUB_CFG"


# ============================================================
# 6. 检查主题
# ============================================================

echo
echo "===== 主题检查 ====="

if [[ -f "$GRUB_THEME_FILE" ]]; then

    echo -e "${bgreen}Lain GRUB Theme 安装成功。${reset}"

else

    echo -e "${bred}错误：主题文件不存在。${reset}"
    exit 1

fi


# ============================================================
# 7. 输出最终配置
# ============================================================

echo
echo "===== 当前 GRUB 设置 ====="

grep -E \
    '^(GRUB_THEME|GRUB_GFXMODE|GRUB_DEFAULT|GRUB_SAVEDEFAULT)=' \
    "$GRUB_DEFAULT" \
    || true


# ============================================================
# 完成
# ============================================================

echo
echo "============================================================"
echo -e "${bgreen}              Lain GRUB Theme 安装完成${reset}"
echo "============================================================"
echo

echo "主题："
echo "  $GRUB_THEME_FILE"

echo
echo "分辨率："
echo "  1920x1080"

echo
echo "默认启动项："
echo "  saved"

echo
echo "记忆上次启动项："
echo "  enabled"

echo
echo "GRUB 配置："
echo "  $GRUB_CFG"

echo
echo -e "下一步可以运行："
echo -e "  ${bcyan}./patch_entries.sh${reset}"
echo
echo "用于进行 GRUB 菜单 Entry 定制。"
echo
echo "============================================================"
