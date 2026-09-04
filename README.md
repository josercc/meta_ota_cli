# meta_ota CLI

单一可执行命令：Shorebird release/patch + 上传到自建 Meta OTA。

## 安装

从 [Releases](https://github.com/josercc/meta_ota_cli/releases/latest) 下载对应平台产物，再按下方步骤安装。

| 平台 | 产物文件名 |
|------|------------|
| Linux x64 | `meta_ota-linux-x64` |
| Windows x64 | `meta_ota-windows-x64.exe` |
| macOS Apple Silicon (M 系列) | `meta_ota-macos-arm64` |
| macOS Intel | `meta_ota-macos-x64` |

不确定 Mac 架构时执行 `uname -m`：`arm64` 选 Apple Silicon，`x86_64` 选 Intel。

### macOS

```bash
# 将下载的文件放到当前目录后（按架构二选一）
chmod +x meta_ota-macos-arm64   # 或 meta_ota-macos-x64
sudo mv meta_ota-macos-arm64 /usr/local/bin/meta_ota

# 首次运行若提示「无法打开 / 已损坏」，去掉隔离属性：
xattr -d com.apple.quarantine /usr/local/bin/meta_ota

meta_ota --help
```

### Linux

```bash
chmod +x meta_ota-linux-x64
sudo mv meta_ota-linux-x64 /usr/local/bin/meta_ota
meta_ota --help
```

也可装到用户目录（无需 sudo）：

```bash
mkdir -p "$HOME/.local/bin"
mv meta_ota-linux-x64 "$HOME/.local/bin/meta_ota"
chmod +x "$HOME/.local/bin/meta_ota"
# 确保 ~/.local/bin 已在 PATH 中
```

### Windows

1. 打开 [Releases](https://github.com/josercc/meta_ota_cli/releases/latest)，下载 `meta_ota-windows-x64.exe`
2. 重命名为 `meta_ota.exe`，放到任意目录，例如 `C:\Tools\meta_ota\`
3. 将该目录加入系统 **PATH**（设置 → 系统 → 关于 → 高级系统设置 → 环境变量）
4. 新开终端验证：

```powershell
meta_ota --help
```

PowerShell 一键示例（管理员可选）：

```powershell
New-Item -ItemType Directory -Force -Path "$env:LOCALAPPDATA\meta_ota" | Out-Null
Move-Item -Force .\meta_ota-windows-x64.exe "$env:LOCALAPPDATA\meta_ota\meta_ota.exe"
# 当前用户 PATH 追加（新开终端后生效）
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$env:LOCALAPPDATA\meta_ota*") {
  [Environment]::SetEnvironmentVariable("Path", "$userPath;$env:LOCALAPPDATA\meta_ota", "User")
}
```

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
