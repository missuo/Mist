# Mist

<div align="center">
  <img src="./AppIcon.png" alt="Mist 图标" width="128" height="128">
  <p><strong>一款原生的 macOS 菜单栏应用，支持 S3 兼容存储和 SM.MS 图床上传</strong></p>

  <p>
    <a href="README.md">English</a> | <b>简体中文</b>
  </p>
</div>

## 概述

Mist 是一款轻量级的原生 macOS 菜单栏应用，旨在简化向云端上传图片和文件的流程。通过拖拽上传、模块化服务商（支持 S3 兼容服务和 SM.MS 图床）、批量处理以及自动剪贴板集成，Mist 极大地提升了文件共享的效率。

## 功能特性

### 核心功能
- **🚀 快速上传**: 直接将文件拖拽到菜单栏图标即可上传
- **📋 自动剪贴板**: 上传完成后自动将文件 URL 复制到剪贴板
- **🔄 批量上传**: 支持多个文件同时上传并实时跟踪进度
- **🖱️ Finder 服务**: 通过右键菜单“服务”直接从访达上传
- **📱 URL Scheme**: 支持通过 `mist://` 协议实现自动化上传

### 支持的服务商
- Amazon S3
- Wasabi
- Cloudflare R2
- Backblaze B2
- MinIO
- 自定义 S3 兼容端点
- SM.MS 图床 (基于 Token，仅限图片)

### 高级特性
- **☁️ iCloud 同步**: 在你所有的 Apple 设备之间同步配置信息
- **🎨 图片处理**: 
  - 实时图片压缩，支持自定义质量
  - 移除 EXIF 元数据以保护隐私
  - 现代格式支持：**AVIF (macOS 13+)**, **WebP (macOS 11+)**, **HEIC (macOS 10.13+)**, 以及 JPEG 和 PNG
  - 旧版本 macOS 的智能格式降级处理
- **⚙️ 多配置管理**: 
  - 管理多个主机配置
  - 在不同主机间快速切换
  - 支持一键克隆配置
- **🎯 灵活的路径模板**: 支持 `{filename}`, `{ext}`, `{year}`, `{month}`, `{day}` 等变量自定义上传路径
- **🔐 安全存储**: 凭据安全地存储在 macOS 系统钥匙串 (Keychain) 中
- **📊 上传历史**: 记录上传成功的项目，支持点击链接直接访问

## 安装

### 下载
从 [Releases](https://github.com/missuo/Mist/releases) 页面下载最新版本。

### 系统要求
- macOS 11.0 (Big Sur) 或更高版本
- 支持 Apple Silicon (M1/M2/M3) 或 Intel 处理器

### 设置
1. 下载并打开 `Mist.dmg`
2. 将 Mist 拖拽到 Applications (应用程序) 文件夹
3. 从应用程序或 Spotlight 启动 Mist
4. 点击菜单栏中的 Mist 图标进入 Preferences (偏好设置)

## 配置说明

### 添加主机

1. 点击菜单栏 Mist 图标
2. 选择 **Preferences** → **Hosts**
3. 点击 **+** 按钮添加新主机
4. 根据服务商配置相关参数：

#### 基础设置
- **Name**: 该配置的友好名称
- **Provider**: 选择 S3 兼容提供商或 SM.MS
- **Region**: AWS S3 必需（其他服务商会根据预设自动调整）
- **Bucket**: S3 存储桶名称（SM.MS 无需此项）
- **Access Key / Secret Key**: S3 凭据（SM.MS 无需此项）
- **Token**: SM.MS API 令牌（仅在选择 SM.MS 时显示）

#### 高级设置
- **Custom Endpoint**: 覆盖默认端点（用于自建 S3 服务）
- **Custom Domain**: 为上传的文件 URL 使用自定义 CDN 域名
- **Save Path Template**: 自定义上传路径结构
  - `{filename}`: 不含后缀的原始文件名
  - `{ext}`: 文件后缀
  - `{year}`, `{month}`, `{day}`: 日期组件
  - `{timestamp}`: Unix 时间戳
  - 示例: `images/{year}/{month}/{filename}.{ext}`
- **ACL**: 设置对象访问控制 (public-read, private 等)

*注意*: SM.MS 上传仅需 API 令牌；S3 相关的字段（存储桶、密钥、ACL、路径、域名）在选中 SM.MS 时会被隐藏。

### 通用设置 (General)

- **Output Format**: 选择图片格式（JPEG, PNG, WebP 或保持原始）
- **Compression Factor**: 调整压缩质量 (0-90)。支持 **AVIF**, **WebP**, **HEIC** 和 **JPEG**。
- **Remove EXIF**: 剥离图片元数据以保护隐私
- **iCloud Sync**: 开启后可跨设备同步配置

## 使用技巧

### 拖拽上传
1. 将一个或多个文件拖到菜单栏 Mist 图标上
2. 文件将自动开始上传
3. 上传完成后，URL 将自动复制到剪贴板
4. 点击系统通知可直接打开链接

### 访达右键上传 (Services)
通过安装 Mist 上传服务实现访达集成：

```bash
./scripts/install-service.sh
```

安装并在系统设置中启用后：
1. 在访达中右键点击一个或多个文件
2. 选择 **服务 (Services)** → **Upload to Mist**

### URL Scheme 上传
使用 `mist://` 协议实现自动化：

```bash
# 上传单个文件
open "mist://files?/path/to/image.png"

# 上传多个文件
open "mist://files?/path/to/file1.jpg,/path/to/file2.png"
```

## 安全性

- **Keychain 集成**: 凭据加密存储在系统钥匙串中
- **应用沙盒**: 在沙盒环境下运行，确保系统安全性
- **无追踪**: Mist 不收集任何使用数据或分析信息
- **本地处理**: 所有图片处理均在本地设备完成

## 开发

### 源码编译

```bash
# 克隆仓库
git clone https://github.com/missuo/Mist.git
cd Mist

# 使用 Xcode 打开
open Mist.xcodeproj

# 编译并运行
# 在 Xcode 中按 Cmd+R
```

## 贡献

欢迎任何形式的贡献！请随时提交 Issue、Fork 仓库或创建 Pull Request。

## 致谢

- 基于原生 macOS 框架构建
- 灵感来源于对简洁、高效文件分享流程的需求
- 感谢所有贡献者和用户

## 贡献者

<a href="https://github.com/missuo/mist/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=missuo/mist" alt="贡献者" />
</a>

## 开源协议

本项目采用 MIT 协议 - 详见 [LICENSE](LICENSE) 文件。

---

<div align="center">
  Made with ❤️ by <a href="https://github.com/missuo">Vincent Yang</a>
</div>
