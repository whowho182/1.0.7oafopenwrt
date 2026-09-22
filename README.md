# OpenWrt x86_64 定制固件（集成 OAF v7.0.1）

通过 **GitHub Actions 云编译**，为 x86/64 软路由生成一套定制 OpenWrt 固件，内置：

- ✅ **OAF（OpenAppFilter）v7.0.1** 上网行为管理插件（应用过滤 / 上网控制 / 上网记录 / MAC 过滤 / 仪表盘）
- ✅ **ext4 可扩容文件系统**（非 squashfs，方便扩容）
- ✅ **根分区 2GB+**（镜像 2G 以上）
- ✅ **分区扩容工具**：`parted`、`e2fsprogs`（resize2fs/tune2fs）、`fdisk`、`cfdisk`、`block-mount`、`blockdev`、`lsblk`
- ✅ **开机自动扩容脚本**：首次启动自动把根分区扩满整块硬盘（适配你的 **14GB 硬盘**）
- ✅ 中文 LuCI 界面

---

## 一、为什么这样配（关键版本事实）

| 项目 | 说明 |
|---|---|
| 基底 OpenWrt | **25.12.5**（OAF v7.0.1 官方基于它编译） |
| 内核 | **6.12.94**（OAF v7.0.1 release 匹配的内核） |
| OAF 源码 | `github.com/destan19/OpenAppFilter` 的 **v7.0.1** tag |
| 包格式 | OpenWrt 25.12 起使用 **APK** 格式（非 opkg），源码编译时自动处理 |
| 为什么源码编译 | OAF 含内核模块 `kmod-oaf`，必须与固件内核精确匹配；源码编译保证内核 6.12.94 完全一致 |

> OAF 官方文档提示“自编译固件不支持”是针对其**现成安装包**的安装路径；本方案是把 OAF **源码直接编进固件**，内核模块随固件一起编译，天然匹配，可正常使用。

---

## 二、目录结构

```
openwrt-oaf-x86/
├── .github/workflows/
│   └── build-openwrt.yml        # GitHub Actions 云编译工作流
├── scripts/
│   ├── setup-build.sh           # 构建主脚本（拉源码/集成OAF/配置/编译）
│   └── resize-root.sh           # 手动扩容脚本（备用）
├── config/rootfs/etc/init.d/
│   └── auto-resize-root         # 开机自动扩容脚本（编入固件）
└── README.md
```

---

## 三、使用步骤

1. **在 GitHub 新建一个仓库**（Public 或 Private 均可），例如 `openwrt-oaf-x86`。
2. 把本目录下**所有文件**上传到该仓库根目录（`.github`、`scripts`、`config`、`README.md` 都保留原层级）。
3. 进入仓库 **Actions** 页面 → 选择 **Build OpenWrt x86_64 (OAF)** 工作流 → 点 **Run workflow**。
4. 等待约 **2~4 小时**（首次源码编译较久）。完成后在对应运行的 **Artifacts** 里下载 `openwrt-oaf-x86_64` 压缩包。
5. 解压得到镜像文件，用 **Rufus / balenaEtcher / dd** 写入硬盘（或 U 盘）。

> 修改 OpenWrt 版本 / OAF 版本 / 根分区大小：编辑 `scripts/setup-build.sh` 顶部的
> `OPENWRT_VERSION`、`OAF_TAG`、`ROOT_PARTSIZE_MB` 三个变量即可。

---

## 四、镜像产物说明

产物位于 `openwrt/bin/targets/x86/64/`，重点关注以下两个（均为 **2GB 根分区**）：

| 文件 | 说明 |
|---|---|
| `openwrt-25.12.5-x86-64-generic-ext4-combined.img.gz` | **BIOS（传统启动）** 通用镜像 |
| `openwrt-25.12.5-x86-64-generic-ext4-combined-efi.img.gz` | **UEFI 启动** 镜像 |

> 老机器用 `combined`，支持 UEFI 的用 `combined-efi`。两个都会生成。
> 镜像根分区默认 2048MB（2GB），若要更大可改 `ROOT_PARTSIZE_MB`。

---

## 五、适配你的 14GB 硬盘（扩容）

固件已内置两套扩容机制，二选一即可：

**方式 A：开机自动扩容（推荐，已编入固件）**
首次启动时，`/etc/init.d/auto-resize-root` 会自动把根分区从 2GB 扩满整块 14GB 硬盘，并自动扩容 ext4 文件系统，无需人工干预。启动后执行 `df -h` 即可看到根分区已变为约 14GB。

**方式 B：手动扩容（备用）**
若自动扩容未生效，可 SSH 登录路由器后执行：

```sh
opkg update
opkg install parted e2fsprogs
parted -f -s /dev/sda resizepart 2 100%
resize2fs /dev/sda2
df -h /
```

> 也可上传并运行仓库里的 `scripts/resize-root.sh` 一键完成。
> 注意：`/dev/sda`、分区号 `2` 以实际 `fdisk -l` 输出为准。

---

## 六、OAF v7.0.1 使用

固件默认集成了 OAF 的：
- `kmod-oaf`（DPI 识别驱动）
- `appfilter`（客户端管理服务）
- `luci-app-oaf`（LuCI 配置界面）

启动后浏览器访问路由器后台（默认 `192.168.1.1`），在左侧菜单找到 **OAF / 应用过滤** 即可配置应用过滤、上网时长、MAC 过滤等。

> 若你希望不刷本固件、而是在**官方 OpenWrt 25.12.5** 基础上单独装 OAF v7.0.1，
> 需按 OAF release 页面安装指引使用 `apk` 命令安装其预编译包（OpenWrt 25.12 为 APK 格式）。

---

## 七、常见问题

**Q1：编译失败或某软件包未选中？**
`setup-build.sh` 内置了关键包校验（luci / luci-app-oaf / parted / e2fsprogs），
若校验失败会中止并提示，方便定位。也可在 Actions 运行日志里搜索 `[FAIL]`。

**Q2：想要更多功能（去广告、科学上网等）？**
在 `setup-build.sh` 的 `.config` 里追加对应的 `CONFIG_PACKAGE_xxx=y`，或在 GitHub 仓库设置里用
`Repository variables` 定义（如 `OPENWRT_VERSION`）后重新运行即可。

**Q3：14GB 硬盘镜像会不会超出？**
不会。镜像本身约 2GB 写入，剩余空间由自动扩容脚本填充使用。

**Q4：编译太慢？**
首次全量编译约 2~4 小时属正常；后续若只改包列表，可考虑改用 OpenWrt ImageBuilder（更快），
但 OAF 含内核模块，仍建议本方案保证版本一致。
