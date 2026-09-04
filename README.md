# meta_ota CLI

单一可执行命令：Shorebird release/patch + 上传到自建 Meta OTA。

## 安装

### 一键安装（推荐）

脚本会自动识别平台、下载 [最新 Release](https://github.com/josercc/meta_ota_cli/releases/latest) 产物并装好。

**macOS / Linux：**

```bash
curl -fsSL https://raw.githubusercontent.com/josercc/meta_ota_cli/main/install.sh | bash
```

默认装到 `/usr/local/bin/meta_ota`（可能需要输入 sudo 密码）。装到用户目录、无需 sudo：

```bash
curl -fsSL https://raw.githubusercontent.com/josercc/meta_ota_cli/main/install.sh | PREFIX=$HOME/.local bash
```

固定版本：

```bash
curl -fsSL https://raw.githubusercontent.com/josercc/meta_ota_cli/main/install.sh | META_OTA_VERSION=v0.1.0 bash
```

**Windows（PowerShell）：**

```powershell
irm https://raw.githubusercontent.com/josercc/meta_ota_cli/main/install.ps1 | iex
```

装到 `%LOCALAPPDATA%\meta_ota` 并写入用户 PATH；新开终端后执行 `meta_ota --help`。

### 手动安装

| 平台 | 产物文件名 |
|------|------------|
| Linux x64 | `meta_ota-linux-x64` |
| Windows x64 | `meta_ota-windows-x64.exe` |
| macOS Apple Silicon (M 系列) | `meta_ota-macos-arm64` |

> macOS Intel 暂无预编译包，请从源码编译：`dart compile exe bin/meta_ota.dart -o meta_ota`。

**macOS（Apple Silicon）：**

```bash
chmod +x meta_ota-macos-arm64
sudo mv meta_ota-macos-arm64 /usr/local/bin/meta_ota
xattr -d com.apple.quarantine /usr/local/bin/meta_ota   # 若提示无法打开
meta_ota --help
```

**Linux：**

```bash
chmod +x meta_ota-linux-x64
sudo mv meta_ota-linux-x64 /usr/local/bin/meta_ota
meta_ota --help
```

**Windows：** 下载 `meta_ota-windows-x64.exe`，重命名为 `meta_ota.exe` 并加入 PATH，或直接用上方一键脚本。

### 前置依赖

本机仍需安装 [Shorebird CLI](https://docs.shorebird.dev)。`meta_ota` 只封装流程，不内嵌 Shorebird。

## 用法

```bash
meta_ota config --api https://ota.customer.com --token <admin-token>
meta_ota release android --app-dir /path/to/flutter_app
meta_ota patch android --app-dir /path/to/flutter_app --version 1.0.0+1
```

配置优先级：`--api` / `--token` > 环境变量 > 项目 `.meta_ota.json` > `~/.meta_ota/config.json`。

## 开发

```bash
dart pub get
dart run bin/meta_ota.dart --help

# 本机编译
dart compile exe bin/meta_ota.dart -o dist/meta_ota
```

## 发布

推送符合 `v*` 的 tag 后，GitHub Actions 会编译 Linux / Windows / macOS 可执行文件并创建 Release：

```bash
git tag v0.1.0
git push origin v0.1.0
```

## 命令一览

| 命令 | 说明 |
|------|------|
| `config` | 写入/查看 API 与 token |
| `release` | `shorebird release`（锁 Flutter、设 `SHOREBIRD_HOSTED_URL`） |
| `patch` | `shorebird patch` + 上传 + promote（可用 `--no-upload`） |
| `upload` | 仅上传已打好的 patch |
| `admin …` | 控制面 API（apps / upload-patch / promote / …） |
| `diff` | 辅助 diff |

## 环境变量

`META_OTA_API`, `META_OTA_TOKEN`, `META_OTA_FLUTTER_VERSION`, `SHOREBIRD_HOSTED_URL`
