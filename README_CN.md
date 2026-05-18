# Mist

<div align="center">
  <img src="./AppIcon.png" alt="Mist 图标" width="128" height="128">
  <p><strong>一款原生 macOS 菜单栏上传工具，支持 S3 兼容存储和 S.EE 图床</strong></p>

  <p>
    <a href="README.md">English</a> | <b>简体中文</b>
  </p>
</div>

## 概述

Mist 是一款轻量级 macOS 菜单栏应用，用于快速上传图片和文件。它支持拖拽上传、Finder 服务、`mist://` URL Scheme、S3 兼容存储和 S.EE 图床。

## 功能

- 拖拽文件到菜单栏图标即可上传
- 上传完成后自动复制 URL
- 支持多文件上传和进度显示
- 支持 Finder 右键服务上传
- 支持通过 `mist://` 从脚本触发上传
- 本地压缩图片、移除 EXIF、转换图片格式
- 通过 iCloud 同步主机配置
- 使用 macOS Keychain 存储凭据

## 支持的服务

- Amazon S3
- Wasabi
- Cloudflare R2
- Backblaze B2
- MinIO
- 自定义 S3 兼容端点
- S.EE 图床

## 安装

从 [Releases](https://github.com/missuo/Mist/releases) 下载最新版，打开 `Mist.dmg`，将 Mist 拖入 Applications。

系统要求：

- macOS 11.0 或更高版本
- Apple Silicon 或 Intel Mac

## 配置

打开 **Preferences** -> **Hosts** 添加主机。

S3 兼容服务需要配置：

- Region 或自定义 Endpoint
- Bucket
- Access Key 和 Secret Key
- 可选的 URL Prefix、ACL、HTTPS 和保存路径模板

S.EE 只需要 API Token。选择 S.EE 后，S3 专用字段会自动隐藏。

保存路径模板支持：

- `{filename}`
- `{ext}`
- `{year}`, `{month}`, `{day}`
- `{timestamp}`
- `{random}`
- `{uuid}`

## 使用

将一个或多个文件拖到 Mist 菜单栏图标上，Mist 会上传文件并将 URL 复制到剪贴板。

Finder 集成：

```bash
./scripts/install-service.sh
```

然后在 System Settings -> Keyboard -> Keyboard Shortcuts -> Services 中启用 **Upload to Mist**。详细说明见 [SERVICES.md](SERVICES.md)。

URL Scheme：

```bash
open "mist://files?/path/to/image.png"
open "mist://files?/path/to/file1.jpg,/path/to/file2.png"
```

## 开发

```bash
git clone https://github.com/missuo/Mist.git
cd Mist
open Mist.xcodeproj
```

Mist 基于 Cocoa、Foundation、CloudKit、UniformTypeIdentifiers 和 UserNotifications 等原生 macOS 框架构建。

## 排错

见 [TROUBLESHOOTING.md](TROUBLESHOOTING.md)。

## 开源协议

MIT。详见 [LICENSE](LICENSE)。
