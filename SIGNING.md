# Mist App 签名和公证指南

## 概述

为了在 macOS 上分发 Mist.app（不通过 App Store），你需要：
1. 使用 **Developer ID Application** 证书签名
2. 通过 Apple 的**公证（Notarization）**服务验证
3. 将公证票据**装订（Staple）**到应用

## 前置要求

### 1. 开发者证书

确保你有 **Developer ID Application** 证书：

```bash
# 查看可用的签名身份
security find-identity -v -p codesigning
```

应该看到类似这样的输出：
```
1) ABC123... "Developer ID Application: Your Name (YOUR_TEAM_ID)"
```

如果没有，需要在 [Apple Developer](https://developer.apple.com/account/resources/certificates/list) 创建。

### 2. App 专用密码

为了使用 `notarytool`，需要创建 App 专用密码：

1. 访问 [appleid.apple.com](https://appleid.apple.com)
2. 登录你的 Apple ID
3. 在"安全"部分，点击"App 专用密码"
4. 点击"生成密码"，输入名称（如 "Mist Notarization"）
5. 保存生成的密码（格式：xxxx-xxxx-xxxx-xxxx）

### 3. 配置信息

记录以下信息：
- **Apple ID**: 你的 Apple Developer 账号邮箱
- **Team ID**: `ZDY6H3JN3N`（在 Xcode 项目中已配置）
- **Developer ID**: 从步骤 1 获取的完整证书名称
- **App Password**: 从步骤 2 获取的专用密码

## 方式一：使用自动化脚本（推荐）

### 1. 配置脚本

编辑 `scripts/sign_and_notarize.sh`，修改以下变量：

```bash
DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (YOUR_TEAM_ID)"
APPLE_ID="your-email@example.com"
APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"
```

### 2. 运行脚本

```bash
cd /path/to/Mist
./scripts/sign_and_notarize.sh
```

脚本会自动完成：
- ✓ 编译 Release 版本
- ✓ 签名应用和扩展
- ✓ 提交公证
- ✓ 装订公证票据
- ✓ 创建签名的 DMG
- ✓ 公证 DMG

完成后，你会得到：
- `build/Release/Mist.app` - 签名并公证的应用
- `build/Release/Mist.dmg` - 签名并公证的安装包

## 方式二：手动步骤

### 步骤 1: 构建 Release 版本

```bash
xcodebuild clean build \
    -project Mist.xcodeproj \
    -scheme Mist \
    -configuration Release \
    -derivedDataPath build \
    CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAM_ID)" \
    CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM="ZDY6H3JN3N"
```

### 步骤 2: 签名应用

```bash
# 先签名扩展
codesign --force --options runtime \
    --sign "Developer ID Application: Your Name (TEAM_ID)" \
    --timestamp \
    --deep \
    "build/Release/Mist.app/Contents/PlugIns/MistShareExtension.appex"

# 再签名主应用
codesign --force --options runtime \
    --sign "Developer ID Application: Your Name (TEAM_ID)" \
    --timestamp \
    --deep \
    "build/Release/Mist.app"

# 验证签名
codesign --verify --deep --strict --verbose=2 "build/Release/Mist.app"
```

### 步骤 3: 创建 ZIP 用于公证

```bash
cd build/Release
ditto -c -k --keepParent Mist.app Mist.zip
cd -
```

### 步骤 4: 提交公证

```bash
xcrun notarytool submit build/Release/Mist.zip \
    --apple-id "your-email@example.com" \
    --team-id "ZDY6H3JN3N" \
    --password "xxxx-xxxx-xxxx-xxxx" \
    --wait
```

这会输出类似：
```
Submission ID received
  id: 12345678-1234-1234-1234-123456789012
Successfully uploaded file
  id: 12345678-1234-1234-1234-123456789012
  path: build/Release/Mist.zip
Waiting for processing to complete...
Current status: Accepted
```

### 步骤 5: 装订公证票据

```bash
xcrun stapler staple "build/Release/Mist.app"
```

### 步骤 6: 验证

```bash
spctl --assess --type execute --verbose=4 "build/Release/Mist.app"
```

应该看到：
```
build/Release/Mist.app: accepted
source=Notarized Developer ID
```

### 步骤 7: 创建 DMG（可选）

```bash
# 创建 DMG
hdiutil create -volname "Mist" \
    -srcfolder "build/Release/Mist.app" \
    -ov -format UDZO \
    "build/Release/Mist.dmg"

# 签名 DMG
codesign --sign "Developer ID Application: Your Name (TEAM_ID)" \
    --timestamp \
    "build/Release/Mist.dmg"

# 公证 DMG
xcrun notarytool submit "build/Release/Mist.dmg" \
    --apple-id "your-email@example.com" \
    --team-id "ZDY6H3JN3N" \
    --password "xxxx-xxxx-xxxx-xxxx" \
    --wait

# 装订 DMG
xcrun stapler staple "build/Release/Mist.dmg"

# 验证 DMG
spctl --assess --type open --context context:primary-signature \
    --verbose=4 "build/Release/Mist.dmg"
```

## 常见问题

### 1. "The application cannot be opened" 错误

**原因**: 应用没有正确签名或公证

**解决方案**:
- 确保使用了 `--options runtime` 标志
- 确保公证成功并装订了票据
- 运行验证命令检查状态

### 2. 公证失败

**原因**: 可能缺少 Hardened Runtime 或有其他问题

**解决方案**:
```bash
# 查看详细的公证日志
xcrun notarytool log <submission-id> \
    --apple-id "your-email@example.com" \
    --team-id "ZDY6H3JN3N" \
    --password "xxxx-xxxx-xxxx-xxxx"
```

### 3. 权限配置（Entitlements）

确保 `Mist.entitlements` 包含：

```xml
<key>com.apple.security.cs.allow-jit</key>
<true/>
<key>com.apple.security.cs.allow-unsigned-executable-memory</key>
<true/>
<key>com.apple.security.cs.disable-library-validation</key>
<true/>
```

（如果你的应用需要这些权限）

### 4. 检查签名详情

```bash
# 查看签名信息
codesign -dv --verbose=4 "build/Release/Mist.app"

# 查看所有签名的组件
codesign -dv --deep "build/Release/Mist.app"

# 查看 entitlements
codesign -d --entitlements - "build/Release/Mist.app"
```

## 分发给用户

签名和公证完成后，你可以：

1. **直接分发 .app**
   - 压缩成 ZIP
   - 用户解压后可以直接运行

2. **分发 DMG**（推荐）
   - 更专业的安装体验
   - 用户拖拽到 Applications 文件夹

3. **通过 GitHub Releases**
   - 上传 DMG 到 GitHub Releases
   - 用户下载后可以直接使用，无警告

## 安全提示

⚠️ **不要将 App 专用密码提交到 Git**

建议使用环境变量或 Keychain：

```bash
# 方式 1: 环境变量
export NOTARIZATION_PASSWORD="xxxx-xxxx-xxxx-xxxx"

# 方式 2: 存储到 Keychain
xcrun notarytool store-credentials "mist-notarization" \
    --apple-id "your-email@example.com" \
    --team-id "ZDY6H3JN3N" \
    --password "xxxx-xxxx-xxxx-xxxx"

# 然后使用存储的凭据
xcrun notarytool submit app.zip --keychain-profile "mist-notarization" --wait
```

## 参考资料

- [Apple Developer: Notarizing macOS Software](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Customizing the Notarization Workflow](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution/customizing_the_notarization_workflow)
- [Code Signing Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/Introduction/Introduction.html)
