#!/bin/sh
# ============================================================
# 手动分区扩容脚本（备用 / 开机自扩失败时在路由器 Shell 中执行）
# 用法：ssh root@<路由器IP> 登录后，粘贴以下内容，或上传后执行 sh resize-root.sh
# 作用：把根分区扩展到整块硬盘并扩容 ext4 文件系统。
# ============================================================
set -e

# 定位根设备
ROOT_BLK="$(readlink -f /dev/root 2>/dev/null)"
[ -n "$ROOT_BLK" ] || ROOT_BLK="$(findmnt -n -o SOURCE /)"
ROOT_DISK="/dev/$(basename "${ROOT_BLK%/*}")"
ROOT_PART="${ROOT_BLK##*[^0-9]}"

echo "磁盘: $ROOT_DISK   根分区: $ROOT_PART"
echo "扩容前:"
df -h /

# 确保分区工具可用
opkg update
opkg install parted e2fsprogs

# 扩展分区到整盘 100%
parted -f -s "$ROOT_DISK" resizepart "$ROOT_PART" 100%
# 扩容文件系统
resize2fs "$ROOT_BLK" || { e2fsck -y -f "$ROOT_BLK"; resize2fs "$ROOT_BLK"; }

echo "扩容后:"
df -h /
echo "完成。"
