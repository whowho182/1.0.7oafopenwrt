#!/bin/bash
# ============================================================
# OpenWrt x86_64 定制固件构建脚本（云编译用）
#   基底：OpenWrt 25.12.5（官方源码）
#   集成：OAF(OpenAppFilter) v7.0.1
#   特性：ext4 可扩容文件系统 / 根分区 2GB / 内置分区扩容工具
#         与开机自动扩容脚本（适配 14GB 硬盘）
# 在 GitHub Actions (ubuntu-24.04) 中执行。
# ============================================================
set -euo pipefail

# ---------- 可调参数（按需修改） ----------
OPENWRT_VERSION="${OPENWRT_VERSION:-v25.12.5}"   # OAF v7.0.1 基于 25.12.5
OAF_TAG="${OAF_TAG:-v7.0.1}"                     # OAF 版本
ROOT_PARTSIZE_MB="${ROOT_PARTSIZE_MB:-2048}"     # 根分区大小（MB），>=2048 即 2GB 以上
JOBS="$(nproc)"
# ------------------------------------------

echo "==> 1/6 拉取 OpenWrt ${OPENWRT_VERSION} 源码"
git clone --depth 1 --branch "${OPENWRT_VERSION}" https://github.com/openwrt/openwrt.git
cd openwrt

echo "==> 2/6 集成 OAF(OpenAppFilter) ${OAF_TAG} 源码"
git clone --depth 1 --branch "${OAF_TAG}" https://github.com/destan19/OpenAppFilter.git package/OpenAppFilter

echo "==> 3/6 更新并安装 feeds"
./scripts/feeds update -a
./scripts/feeds install -a

echo "==> 4/6 写入编译配置（x86_64 / ext4 / 根分区 ${ROOT_PARTSIZE_MB}MB）"
cat > .config <<EOF
# --- 目标平台：x86_64 ---
CONFIG_TARGET_x86=y
CONFIG_TARGET_x86_64=y
CONFIG_TARGET_x86_64_Generic=y

# --- 根文件系统：仅 ext4（可扩容），根分区大小 ---
CONFIG_TARGET_ROOTFS_EXT4FS=y
CONFIG_TARGET_ROOTFS_SQUASHFS=n
CONFIG_TARGET_ROOTFS_PARTSIZE=${ROOT_PARTSIZE_MB}

# --- 生成 BIOS 与 UEFI 两种 combined 镜像 ---
CONFIG_GRUB_IMAGES=y
CONFIG_GRUB_EFI_IMAGES=y

# --- 基础 LuCI 与中文语言包 ---
CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_luci-i18n-base-zh-cn=y

# --- OAF（OpenAppFilter）上网行为管理 ---
CONFIG_PACKAGE_luci-app-oaf=y

# --- 分区扩容工具（14GB 硬盘自动/手动扩容用）---
CONFIG_PACKAGE_parted=y
CONFIG_PACKAGE_e2fsprogs=y
CONFIG_PACKAGE_fdisk=y
CONFIG_PACKAGE_cfdisk=y
CONFIG_PACKAGE_block-mount=y
CONFIG_PACKAGE_blockdev=y
CONFIG_PACKAGE_lsblk=y
EOF

echo "==> 5/6 展开为完整配置"
make defconfig

# 校验关键软件包确实被选中（防止符号名写错导致漏编译）
echo "==> 校验关键软件包是否选中"
for pkg in luci luci-app-oaf parted e2fsprogs; do
  if grep -q "CONFIG_PACKAGE_${pkg}=y" .config; then
    echo "  [OK] CONFIG_PACKAGE_${pkg}"
  else
    echo "  [FAIL] CONFIG_PACKAGE_${pkg} 未选中，编译中止" >&2
    exit 1
  fi
done

# 拷贝自带的开机自动扩容脚本到固件 files 目录
echo "==> 注入开机自动扩容脚本"
mkdir -p files/etc/init.d
cp "${GITHUB_WORKSPACE:-..}/config/rootfs/etc/init.d/auto-resize-root" files/etc/init.d/
chmod +x files/etc/init.d/auto-resize-root

echo "==> 6/6 开始编译（约需 2-4 小时，请耐心等待）"
make -j"${JOBS}" V=s

echo "==> 构建完成，产物位于："
echo "    openwrt/bin/targets/x86/64/"
ls -lh bin/targets/x86/64/*.gz 2>/dev/null || ls -lh bin/targets/x86/64/
