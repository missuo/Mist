# Mist 构建和签名脚本

## 脚本列表

### 1. `build_release.sh` - 快速构建
用于本地测试的快速构建脚本。

```bash
./scripts/build_release.sh
```

**输出**: `build/Release/Mist.app`（未签名，仅供本地测试）

---

### 2. `sign_and_notarize.sh` - 完整签名和公证
用于生产环境的完整签名和公证流程。

#### 首次使用：配置脚本

编辑 `sign_and_notarize.sh`，修改以下变量：

```bash
# 1. 查找你的签名身份
security find-identity -v -p codesigning

# 2. 复制完整的证书名称（类似 "Developer ID Application: Your Name (TEAM_ID)"）
DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAM_ID)"

# 3. 设置你的 Apple ID
APPLE_ID="your-email@example.com"

# 4. 创建并设置 App 专用密码（从 appleid.apple.com 获取）
APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"
```

#### 运行

```bash
./scripts/sign_and_notarize.sh
```

**流程**:
1. 构建 Release 版本
2. 签名应用（使用 Developer ID）
3. 提交到 Apple 公证服务
4. 等待公证完成（可能需要 5-15 分钟）
5. 装订公证票据
6. 创建并签名 DMG
7. 公证 DMG
8. 装订 DMG

**输出**:
- `build/Release/Mist.app` - 签名并公证的应用
- `build/Release/Mist.dmg` - 签名并公证的安装包

---

## 工作流程

### 开发阶段
```bash
# 使用 Xcode 直接运行
open Mist.xcodeproj

# 或快速构建 Release 版本测试
./scripts/build_release.sh
```

### 发布阶段
```bash
# 1. 更新版本号（在 Xcode 中）
# 2. 提交所有代码更改
git add .
git commit -m "chore: prepare for release vX.X.X"
git tag vX.X.X
git push origin main --tags

# 3. 签名和公证
./scripts/sign_and_notarize.sh

# 4. 上传到 GitHub Releases
# - 在 GitHub 创建新 Release
# - 上传 build/Release/Mist.dmg
```

---

## 安全最佳实践

### 不要提交密码到 Git

**方式 1**: 使用环境变量

```bash
# 在 ~/.zshrc 或 ~/.bash_profile 添加
export MIST_NOTARIZATION_PASSWORD="xxxx-xxxx-xxxx-xxxx"

# 脚本中使用
APP_PASSWORD="${MIST_NOTARIZATION_PASSWORD}"
```

**方式 2**: 使用 Keychain Profile（推荐）

```bash
# 一次性设置
xcrun notarytool store-credentials "mist-notarization" \
    --apple-id "your-email@example.com" \
    --team-id "NCFNX3LJ83" \
    --password "xxxx-xxxx-xxxx-xxxx"

# 在脚本中使用
xcrun notarytool submit app.zip \
    --keychain-profile "mist-notarization" \
    --wait
```

---

## 故障排查

### 查看可用的签名身份
```bash
security find-identity -v -p codesigning
```

### 查看应用的签名信息
```bash
codesign -dv --verbose=4 build/Release/Mist.app
```

### 验证公证状态
```bash
spctl --assess --type execute --verbose=4 build/Release/Mist.app
```

### 查看公证日志
```bash
# 从公证提交时获取的 ID
xcrun notarytool log <submission-id> \
    --apple-id "your-email@example.com" \
    --team-id "NCFNX3LJ83" \
    --password "xxxx-xxxx-xxxx-xxxx"
```

### 测试 Gatekeeper
```bash
# 在其他 Mac 上测试（或删除扩展属性后测试）
xattr -d com.apple.quarantine build/Release/Mist.app
spctl --assess --verbose build/Release/Mist.app
```

---

## 更多信息

详细的签名和公证指南，请参阅 [SIGNING.md](../SIGNING.md)
