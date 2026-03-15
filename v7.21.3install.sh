#!/bin/bash
# ==================================================
# RouterOS v7.21.3 GitHub 一键重装脚本 (通用版)
# 源仓库: qq48674431/jing-routeros-dong
# ==================================================

# --- 1. 用户配置区 ---
# 设置你的 ROS 系统密码 (建议修改这里)
ROS_PASSWORD="Admin112233" 

# --- 2. 环境检测与镜像匹配 ---
GITHUB_REPO="qq48674431/jing-routeros-dong"
TAG="v7.21.3"

if [ -d /sys/firmware/efi ]; then
    echo "环境检测: [UEFI 模式]"
    # UEFI 使用标准包
    IMG_URL="https://github.com/qq48674431/jing-routeros-dong/releases/download/v7.21.3/chr-7.20.6.img"
else
    echo "环境检测: [BIOS 模式]"
    # BIOS 使用 Legacy 专用包
    IMG_URL="https://github.com/${GITHUB_REPO}/releases/download/${TAG}/chr-7.21.3-legacy-bios.img"
fi

# --- 3. 下载镜像 ---
echo "正在从 GitHub 下载镜像..."
echo "下载地址: $IMG_URL"

# 使用 curl 下载，-L 跟随跳转 (GitHub 需要)，-f 失败报错
curl -L -f -o /tmp/chr.img "$IMG_URL" --connect-timeout 20 --retry 3

# 下载检测
if [ $? -ne 0 ]; then
    echo "Error: 下载失败！"
    echo "请检查服务器是否能访问 GitHub (国外源)，或 DNS 配置。"
    exit 1
fi

# --- 4. 备份当前网络信息 ---
# 获取当前IP和网关 (防止安装后失联)
ETH=$(ip route show default | sed -n 's/.* dev \([^\ ]*\) .*/\1/p' | head -n 1)
ADDRESS=$(ip addr show "$ETH" | grep global | awk '{print $2}' | head -n 1)
GATEWAY=$(ip route list | grep default | awk '{print $3}' | head -n 1)

if [ -z "$ADDRESS" ] || [ -z "$GATEWAY" ]; then
    echo "Error: 无法自动获取 IP 或网关，脚本终止以防失联。"
    exit 1
fi

echo "保留网络配置: IP=$ADDRESS | 网关=$GATEWAY"

# --- 5. 离线注入配置 (losetup 方式) ---
echo "正在注入配置到镜像..."
mkdir -p /mnt/ros_tmp

# 挂载镜像 (使用 -P 自动识别分区)
LOOPDEV=$(losetup -f --show -P /tmp/chr.img)
if [ -z "$LOOPDEV" ]; then
    echo "Error: losetup 挂载失败 (可能是内核版本过低不支持 -P 参数)"
    exit 1
fi
sleep 1

# 寻找包含 rw 目录的分区 (通常是第二个分区)
FOUND_PART=""
for part in "${LOOPDEV}"p{1..5} "${LOOPDEV}"{1..5}; do
    [ -e "$part" ] || continue
    mount "$part" /mnt/ros_tmp 2>/dev/null
    if [ -d /mnt/ros_tmp/rw ]; then
        FOUND_PART="$part"
        break
    else
        umount /mnt/ros_tmp 2>/dev/null
    fi
done

if [ -z "$FOUND_PART" ]; then
    echo "Error: 无法在镜像中找到 rw 配置目录，注入失败。"
    losetup -d "$LOOPDEV"
    exit 1
fi

# 写入 autorun.scr
cat > /mnt/ros_tmp/rw/autorun.scr <<EOF
/user set [find name=admin] password="$ROS_PASSWORD"
/interface ethernet set [ find default-name=ether1 ] name=wan
/ip address add address=$ADDRESS interface=wan
/ip route add gateway=$GATEWAY
/ip service set telnet disabled=yes
/ip service set ssh disabled=no port=22
/ip service set winbox disabled=no
EOF

echo "配置注入成功！(挂载分区: $FOUND_PART)"
sync
umount /mnt/ros_tmp
losetup -d "$LOOPDEV"

# --- 6. 写入硬盘 ---
STORAGE=$(lsblk -dn -o NAME,TYPE | awk '$2=="disk"{print $1; exit}')
if [ -z "$STORAGE" ]; then echo "Error: 找不到物理硬盘"; exit 1; fi

echo "---------------------------------------------"
echo "即将写入目标硬盘: /dev/$STORAGE"
echo "SSH 密码将重置为: $ROS_PASSWORD"
echo "---------------------------------------------"
echo "正在写入 (请勿断电)..."

dd if=/tmp/chr.img of=/dev/"$STORAGE" bs=4M oflag=sync status=progress

# --- 7. 重启 ---
echo "安装完成！3秒后重启系统..."
sleep 3
echo 1 > /proc/sys/kernel/sysrq
echo b > /proc/sysrq-trigger
