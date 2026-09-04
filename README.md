# meta_ota CLI

单一可执行命令：Shorebird release/patch + 上传到自建 Meta OTA。

## 安装

从 [Releases](../../releases) 下载对应平台二进制，或打 tag 后由 CI 自动构建：

| 平台 | 产物 |
|------|------|
| Linux x64 | `meta_ota-linux-x64` |
| Windows x64 | `meta_ota-windows-x64.exe` |
| macOS Apple Silicon | `meta_ota-macos-arm64` |
| macOS Intel | `meta_ota-macos-x64` |

```bash
# 示例（macOS arm64）
chmod +x meta_ota-macos-arm64
sudo mv meta_ota-macos-arm64 /usr/local/bin/meta_ota
```

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
