#!/usr/bin/env bash

# ============================================================
# GRUB / grub-btrfs 通用定制脚本
#
# 功能：
#   1. Windows 条目移到 Linux 前面
#   2. Windows Boot Manager → Windows
#   3. 删除 Windows 条目的分区信息
#   4. Linux 主菜单名称简化
#   5. Advanced options → Options
#   6. UEFI Firmware Settings 添加 class
#   7. Snapshot 菜单添加 recovery / snapper / snapshots class
#   8. Snapshot 菜单名称 → <发行版> Snapshots
#   9. 禁用 EFI BootNext
#  10. Snapshot 显示：date + description
#  11. 隐藏 Snapper pre snapshots
#  12. 自动备份被修改的 GRUB 文件
#  13. 支持重复执行
#  14. 自动检查并生成 grub.cfg
#
# 设计原则：
#   - 不依赖特定发行版的 grub-btrfs 配置扩展
#   - Snapshot 菜单名称直接 patch 41_snapshots-btrfs
#   - Snapshot class 直接 patch 41_snapshots-btrfs
#   - grub-btrfs 显示设置使用 /etc/default/grub-btrfs/config
#   - 原始文件只备份一次
#   - 脚本可以安全重复执行
# ============================================================

set -u
set -o pipefail


# ============================================================
# 0. 基础环境
# ============================================================

if [[ $EUID -eq 0 ]]; then
    SUDO=""
else
    SUDO="sudo"
fi

# 普通用户必须有 sudo
if [[ -n "$SUDO" ]] && ! command -v sudo >/dev/null 2>&1; then
    echo "错误：当前用户不是 root，且找不到 sudo。"
    exit 1
fi

echo
echo "============================================================"
echo "        GRUB / grub-btrfs Customization"
echo "============================================================"
echo


# ============================================================
# 1. 路径
# ============================================================

GRUB_DIR="/etc/grub.d"

GRUB_LINUX="$GRUB_DIR/10_linux"
GRUB_UEFI="$GRUB_DIR/30_uefi-firmware"
GRUB_BOOTNEXT="$GRUB_DIR/31_efi_bootnext"

GRUB_BTRFS_SCRIPT="$GRUB_DIR/41_snapshots-btrfs"
GRUB_BTRFS_CONFIG="/etc/default/grub-btrfs/config"

GRUB_CFG="/boot/grub/grub.cfg"

BACKUP_DIR="$GRUB_DIR/backup-grub-custom"


# ============================================================
# 2. 检查基础文件
# ============================================================

echo "===== 检查 GRUB 环境 ====="

if [[ ! -d "$GRUB_DIR" ]]; then
    echo "错误：$GRUB_DIR 不存在。"
    exit 1
fi

if [[ ! -f "$GRUB_LINUX" ]]; then
    echo "错误：找不到 $GRUB_LINUX"
    exit 1
fi

if [[ ! -f "$GRUB_CFG" ]]; then
    echo "提示：$GRUB_CFG 当前不存在，将在最后生成。"
fi


# ============================================================
# 3. 检查 grub-btrfs
# ============================================================

if [[ -f "$GRUB_BTRFS_SCRIPT" ]]; then
    GRUB_BTRFS_AVAILABLE=1
    echo "检测到：$GRUB_BTRFS_SCRIPT"
else
    GRUB_BTRFS_AVAILABLE=0
    echo "提示：没有找到 $GRUB_BTRFS_SCRIPT"
    echo "      grub-btrfs Snapshot 定制将跳过。"
fi


# ============================================================
# 4. 创建备份目录
# ============================================================

echo
echo "===== 创建备份目录 ====="

$SUDO mkdir -p "$BACKUP_DIR"


# ============================================================
# 5. 备份函数
# ============================================================

backup_file() {

    local file="$1"

    if [[ ! -f "$file" ]]; then
        return 0
    fi

    local name
    name="$(basename "$file")"

    # 只保留第一次运行时的原始文件
    if [[ ! -f "$BACKUP_DIR/$name" ]]; then

        echo "备份：$file"

        $SUDO cp -a \
            "$file" \
            "$BACKUP_DIR/$name"

    else

        echo "已存在原始备份：$BACKUP_DIR/$name"

    fi
}


# ============================================================
# 6. 备份所有可能修改的 GRUB 文件
# ============================================================

echo
echo "===== 备份 GRUB 文件 ====="

backup_file "$GRUB_LINUX"
backup_file "$GRUB_UEFI"
backup_file "$GRUB_BTRFS_SCRIPT"
backup_file "$GRUB_DIR/30_os-prober"
backup_file "$GRUB_DIR/05_os-prober"
backup_file "$GRUB_BOOTNEXT"


# ============================================================
# 7. OS-Prober
# ============================================================

echo
echo "===== 1. OS-Prober ====="

OS_PROBER=""

if [[ -f "$GRUB_DIR/30_os-prober" ]]; then

    OS_PROBER="$GRUB_DIR/30_os-prober"

elif [[ -f "$GRUB_DIR/05_os-prober" ]]; then

    OS_PROBER="$GRUB_DIR/05_os-prober"

fi


if [[ -n "$OS_PROBER" ]]; then

    echo "检测到：$OS_PROBER"


    # --------------------------------------------------------
    # 7.1 删除 Windows 分区信息
    #
    # 原：
    #   (on /dev/nvme...)
    #
    # 改：
    #   空
    # --------------------------------------------------------

    if grep -q \
        'onstr="$(gettext_printf "(on %s)" "${DEVICE}")"' \
        "$OS_PROBER"; then

        $SUDO sed -i \
            's/onstr="$(gettext_printf "(on %s)" "${DEVICE}")"/onstr=""/g' \
            "$OS_PROBER"

        echo "已删除 Windows 分区信息。"

    else

        echo "Windows 分区信息已经修改，或当前版本结构不同。"

    fi


    # --------------------------------------------------------
    # 7.2 Windows Boot Manager → Windows
    # --------------------------------------------------------

    if grep -q 'LONGNAME=' "$OS_PROBER"; then

        if grep -q 'cut -d.*-f 2' "$OS_PROBER"; then

            $SUDO sed -i \
                's/LONGNAME="`echo ${OS} | cut -d '"'"':'"'"' -f 2 | tr '"'"'^'"'"' '"'"' '"'"'`"/LONGNAME="`echo ${OS} | cut -d '"'"':'"'"' -f 3 | tr '"'"'^'"'"' '"'"' '"'"'`"/g' \
                "$OS_PROBER"

            echo "已简化 Windows 名称。"

        else

            echo "Windows 名称可能已经修改。"

        fi

    fi


    # --------------------------------------------------------
    # 7.3 Windows 放到 Linux 前面
    #
    # 30_os-prober
    #       ↓
    # 05_os-prober
    # --------------------------------------------------------

    if [[ "$OS_PROBER" == "$GRUB_DIR/30_os-prober" ]]; then

        if [[ ! -e "$GRUB_DIR/05_os-prober" ]]; then

            $SUDO mv \
                "$GRUB_DIR/30_os-prober" \
                "$GRUB_DIR/05_os-prober"

            echo "已将：30_os-prober → 05_os-prober"

        else

            echo "05_os-prober 已存在。"

            # 两个文件同时存在时，禁用旧的 30_os-prober
            if [[ -f "$GRUB_DIR/30_os-prober" ]]; then

                $SUDO chmod -x \
                    "$GRUB_DIR/30_os-prober"

                echo "已禁用重复的 30_os-prober。"

            fi

        fi

    else

        # 确保 05_os-prober 可执行
        if [[ -f "$GRUB_DIR/05_os-prober" ]]; then

            $SUDO chmod +x \
                "$GRUB_DIR/05_os-prober"

            echo "05_os-prober 已确保可执行。"

        fi

    fi

else

    echo "提示：没有找到 30_os-prober 或 05_os-prober。"

fi


# ============================================================
# 8. Linux 主菜单名称
# ============================================================

echo
echo "===== 2. Linux 主菜单 ====="

if grep -q \
    'title="$(gettext_printf "%s, with Linux %s" "${os}" "${version}")"' \
    "$GRUB_LINUX"; then

    $SUDO sed -i \
        's/title="$(gettext_printf "%s, with Linux %s" "${os}" "${version}")"/title="${os}"/' \
        "$GRUB_LINUX"

    echo "Linux 主菜单名称已简化。"

elif grep -q \
    'title="${os}"' \
    "$GRUB_LINUX"; then

    echo "Linux 主菜单已经简化。"

else

    echo "警告：当前 10_linux 版本没有找到预期标题格式。"
    echo "未进行修改，以避免破坏 GRUB。"

fi


# ============================================================
# 9. Advanced Options
# ============================================================

echo
echo "===== 3. Advanced Options ====="

ADVANCED_PATTERN='gettext_printf "Advanced options for %s" "\${OS}"'

if grep -qF \
    "$ADVANCED_PATTERN" \
    "$GRUB_LINUX"; then

    $SUDO sed -i \
        's/gettext_printf "Advanced options for %s" "\${OS}" | grub_quote)/gettext_printf "Options for %s" "\${OS}" | cut -d '"'"' '"'"' -f1,2,3 | grub_quote)/g' \
        "$GRUB_LINUX"

    echo "Advanced options → Options"

elif grep -q \
    'gettext_printf "Options for %s"' \
    "$GRUB_LINUX"; then

    echo "Advanced Options 已经修改。"

else

    echo "警告：当前 10_linux 版本未匹配 Advanced options。"
    echo "未修改。"

fi


# ============================================================
# 10. UEFI Firmware Settings class
# ============================================================

echo
echo "===== 4. UEFI Firmware Settings ====="

if [[ -f "$GRUB_UEFI" ]]; then

    if grep -q \
        -- '--class uefi_firmware_settings' \
        "$GRUB_UEFI"; then

        echo "UEFI Firmware Settings class 已存在。"

    elif grep -q \
        'menuentry.*\$LABEL.*\$menuentry_id_option' \
        "$GRUB_UEFI"; then

        $SUDO sed -i \
            's/menuentry '"'"'$LABEL'"'"' \\$menuentry_id_option/menuentry '"'"'$LABEL'"'"' --class uefi_firmware_settings \\$menuentry_id_option/g' \
            "$GRUB_UEFI"

        echo "已添加：uefi_firmware_settings class"

    else

        echo "警告：当前 30_uefi-firmware 结构无法匹配。"
        echo "未修改。"

    fi

else

    echo "跳过：没有 30_uefi-firmware。"

fi


# ============================================================
# 11. grub-btrfs
# ============================================================

if [[ "$GRUB_BTRFS_AVAILABLE" -eq 1 ]]; then

    echo
    echo "===== 5. grub-btrfs ====="


    # ========================================================
    # 11.1 Snapshot class
    #
    # 必须同时存在：
    #
    #   --class recovery
    #   --class snapper
    #   --class snapshots
    #
    # 
    # ========================================================

    echo
    echo "----- Snapshot classes -----"

    if grep -qE \
        "submenu '.*\\\${submenuname}.*--class recovery --class snapper --class snapshots" \
        "$GRUB_BTRFS_SCRIPT"; then

        echo "Snapshot classes 已完整存在："
        echo "  recovery"
        echo "  snapshot"
        echo "  snapshots"

    else

        if grep -q \
            "submenu '\${submenuname}' \${protection_authorized_users}\${unrestricted_access_submenu}{" \
            "$GRUB_BTRFS_SCRIPT"; then

            $SUDO sed -i \
                's/submenu '\''${submenuname}'\'' ${protection_authorized_users}${unrestricted_access_submenu}{/submenu '\''${submenuname}'\'' --class recovery --class snapper --class snapshots ${protection_authorized_users}${unrestricted_access_submenu}{/' \
                "$GRUB_BTRFS_SCRIPT"

            echo "已添加 Snapshot classes："
            echo "  recovery"
            echo "  snapper"
            echo "  snapshots"

        else

            echo "警告：当前 grub-btrfs 版本没有匹配 Snapshot submenu。"
            echo "未修改。"

        fi

    fi


    # ========================================================
    # 11.2 Snapshot 菜单名称
    #
    # 使用动态发行版名称：
    #
    #   CachyOS → CachyOS Snapshots
    #   Arch    → Arch Snapshots
    #   Debian  → Debian Snapshots
    #   Linux   → Linux Snapshots
    # ========================================================

    echo
    echo "----- Snapshot 菜单名称 -----"

    if grep -q \
        '"${distro:-Linux} Snapshots"' \
        "$GRUB_BTRFS_SCRIPT"; then

        echo 'Snapshot 菜单已经是：${distro:-Linux} Snapshots'

    elif grep -q \
        '"${distro:-Linux} snapshots"' \
        "$GRUB_BTRFS_SCRIPT"; then

        $SUDO sed -i \
            's/"${distro:-Linux} snapshots"/"${distro:-Linux} Snapshots"/' \
            "$GRUB_BTRFS_SCRIPT"

        echo "Snapshot 菜单名称已修改："
        echo "  ${distro:-Linux} snapshots"
        echo "       ↓"
        echo "  ${distro:-Linux} Snapshots"

    else

        echo "警告：当前 grub-btrfs 版本没有找到默认 snapshots 标题。"
        echo "可能该版本已经改变菜单名称实现方式。"
        echo "未强制修改。"

    fi


    # ========================================================
    # 11.3 grub-btrfs snapshot 配置
    # ========================================================

    echo
    echo "----- grub-btrfs snapshot 配置 -----"

    $SUDO install \
        -d \
        -m 755 \
        /etc/default/grub-btrfs

    if [[ ! -f "$GRUB_BTRFS_CONFIG" ]]; then

        $SUDO touch \
            "$GRUB_BTRFS_CONFIG"

        echo "创建：$GRUB_BTRFS_CONFIG"

    fi


    # 删除旧配置，防止重复
    $SUDO sed -i \
        -e '/^GRUB_BTRFS_TITLE_FORMAT=/d' \
        -e '/^GRUB_BTRFS_IGNORE_SNAPSHOT_TYPE=/d' \
        "$GRUB_BTRFS_CONFIG"


    # 写入新的配置
    $SUDO tee -a \
        "$GRUB_BTRFS_CONFIG" >/dev/null <<'EOF'

# ============================================================
# Custom grub-btrfs snapshot display
# ============================================================

# Snapshot 菜单显示：
#   日期 + Snapper description
GRUB_BTRFS_TITLE_FORMAT=("date" "description")

# 隐藏 Snapper pre snapshot
# 保留 post / single snapshot
GRUB_BTRFS_IGNORE_SNAPSHOT_TYPE=("pre")
EOF


    echo "已设置："
    echo '  GRUB_BTRFS_TITLE_FORMAT=("date" "description")'
    echo '  GRUB_BTRFS_IGNORE_SNAPSHOT_TYPE=("pre")'


else

    echo
    echo "===== 5. grub-btrfs ====="
    echo "未安装 grub-btrfs，跳过 Snapshot 定制。"

fi


# ============================================================
# 12. EFI BootNext
# ============================================================

echo
echo "===== 6. EFI BootNext ====="

if [[ -f "$GRUB_BOOTNEXT" ]]; then

    if [[ -x "$GRUB_BOOTNEXT" ]]; then

        $SUDO chmod -x \
            "$GRUB_BOOTNEXT"

        echo "已禁用：31_efi_bootnext"

    else

        echo "31_efi_bootnext 已经禁用。"

    fi

else

    echo "系统没有 31_efi_bootnext，跳过。"

fi


# ============================================================
# 13. 检查 GRUB 脚本权限
# ============================================================

echo
echo "===== 7. 检查 GRUB 脚本权限 ====="


# ------------------------------------------------------------
# 13.1 05_os-prober 必须可执行
# ------------------------------------------------------------

if [[ -f "$GRUB_DIR/05_os-prober" ]]; then

    $SUDO chmod +x \
        "$GRUB_DIR/05_os-prober"

fi


# ------------------------------------------------------------
# 13.2 如果 30 和 05 同时存在
#     禁用 30，避免 Windows 出现两次
# ------------------------------------------------------------

if [[ -f "$GRUB_DIR/30_os-prober" &&
      -f "$GRUB_DIR/05_os-prober" ]]; then

    $SUDO chmod -x \
        "$GRUB_DIR/30_os-prober"

    echo "检测到重复 os-prober："
    echo "  已禁用 30_os-prober"

fi


# ============================================================
# 14. 生成 GRUB
# ============================================================

echo
echo "============================================================"
echo "                 生成 GRUB 配置"
echo "============================================================"
echo

if ! command -v grub-mkconfig >/dev/null 2>&1; then

    echo "错误：找不到 grub-mkconfig。"
    exit 1

fi


if ! $SUDO grub-mkconfig \
    -o "$GRUB_CFG"; then

    echo
    echo "============================================================"
    echo "错误：grub-mkconfig 生成失败！"
    echo "============================================================"
    echo
    echo "本次修改没有自动回滚。"
    echo
    echo "原始文件备份位于："
    echo "  $BACKUP_DIR"
    echo

    exit 1

fi


# ============================================================
# 15. GRUB 配置语法检查
# ============================================================

echo
echo "===== 9. GRUB 配置检查 ====="

if command -v grub-script-check >/dev/null 2>&1; then

    if $SUDO grub-script-check \
        "$GRUB_CFG"; then

        echo "GRUB 配置语法检查：通过"

    else

        echo
        echo "警告：grub-script-check 检查失败。"
        echo "请不要立即重启。"
        echo "建议先检查："
        echo "  $GRUB_CFG"

    fi

else

    echo "系统没有 grub-script-check，跳过。"

fi


# ============================================================
# 16. 最终结果
# ============================================================

echo
echo "============================================================"
echo "                    配置完成"
echo "============================================================"
echo

echo "备份目录："
echo "  $BACKUP_DIR"

echo
echo "GRUB 配置文件："
echo "  $GRUB_CFG"


# ------------------------------------------------------------
# Snapshot 配置
# ------------------------------------------------------------

echo
echo "GRUB 快照配置："

if [[ -f "$GRUB_BTRFS_CONFIG" ]]; then

    grep -nE \
        '^GRUB_BTRFS_(TITLE_FORMAT|IGNORE_SNAPSHOT_TYPE)=' \
        "$GRUB_BTRFS_CONFIG" \
        || true

fi


# ------------------------------------------------------------
# GRUB 菜单
#
# 去掉缩进，让最终输出更加直观。
# 这里只影响脚本输出，不影响 grub.cfg。
# ------------------------------------------------------------

echo
echo "当前 GRUB 菜单相关项目："

$SUDO grep -E \
    '^[[:space:]]*(menuentry|submenu) ' \
    "$GRUB_CFG" \
    | sed -E 's/^[[:space:]]+//' \
    | grep -E \
        'Windows|CachyOS|Linux|Snapshot|Firmware|Options' \
    | head -40 \
    || true


# ------------------------------------------------------------
# Snapshot class 最终验证
# ------------------------------------------------------------

echo
echo "Snapshot submenu class："

$SUDO grep -E \
    "^submenu .*--class recovery .*--class snapper .*--class snapshots" \
    "$GRUB_CFG" \
    | head -10 \
    || true


# ------------------------------------------------------------
# EFI BootNext 最终验证
# ------------------------------------------------------------

echo
echo "EFI BootNext："

if [[ -f "$GRUB_BOOTNEXT" ]]; then

    if [[ -x "$GRUB_BOOTNEXT" ]]; then
        echo "  警告：31_efi_bootnext 仍然是可执行状态。"
    else
        echo "  已禁用：31_efi_bootnext"
    fi

else

    echo "  系统没有 31_efi_bootnext"

fi


# ============================================================
# 17. 完成
# ============================================================

echo
echo "============================================================"
echo "完成。"
echo
echo "建议先检查上面的 GRUB 条目。"
echo "确认无误后再重启。"
echo "============================================================"
echo

