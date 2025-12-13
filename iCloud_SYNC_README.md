# iCloud 同步功能实现说明

## 已完成的工作

### 1. 权限配置
- ✅ 在主应用和 ShareExtension 的 entitlements 文件中添加了 iCloud Key-Value Storage 权限
- ✅ 使用 `NSUbiquitousKeyValueStore` 实现配置同步

### 2. 创建的文件
- **MSTiCloudSyncManager.h** - iCloud 同步管理器头文件
- **MSTiCloudSyncManager.m** - iCloud 同步管理器实现文件

### 3. 修改的文件
- **MSTConfigManager.h** - 添加了 iCloud 同步相关属性
- **MSTConfigManager.m** - 集成了 iCloud 同步功能
- **MSTConstants.h/m** - 添加了 iCloud 数据变化通知
- **Mist.entitlements** - 添加了 iCloud 权限
- **ShareExtension.entitlements** - 添加了 iCloud 权限

## 功能特性

### iCloud 同步内容
- ✅ Hosts 配置列表
- ✅ 默认 Host ID
- ✅ 输出格式设置
- ✅ 压缩因子设置
- ✅ 移除 EXIF 设置

### 同步机制
- **自动同步**：保存配置时自动同步到 iCloud
- **自动加载**：启动时优先从 iCloud 加载配置（如果启用）
- **实时更新**：监听 iCloud 数据变化，其他设备的修改会实时同步
- **本地缓存**：即使禁用 iCloud，也保持本地配置正常工作

### 使用的 API
- `NSUbiquitousKeyValueStore` - 用于轻量级配置数据同步
- 限制：每个应用最多 1MB 存储空间，单个 key 最大 1MB
- 优点：自动处理冲突，Apple 推荐用于偏好设置同步

## 需要完成的步骤

### 1. 在 Xcode 中添加新文件（必须）
你需要在 Xcode 项目中添加以下文件：
1. 打开 `Mist.xcodeproj`
2. 将以下文件添加到 `Services` 组：
   - `Mist/Services/MSTiCloudSyncManager.h`
   - `Mist/Services/MSTiCloudSyncManager.m`
3. 确保这两个文件的 Target Membership 包含主应用和 ShareExtension

### 2. 在 Xcode 中配置 iCloud（必须）
1. 选择项目 Target (Mist)
2. 在 "Signing & Capabilities" 标签页
3. 点击 "+ Capability" 按钮
4. 添加 "iCloud" capability
5. 勾选 "Key-value storage"
6. 对 ShareExtension Target 重复相同步骤

### 3. 添加 UI 控制（推荐）
建议在设置界面添加一个开关来控制 iCloud 同步：

```objective-c
// 在设置视图控制器中

// 检查 iCloud 是否可用
if ([MSTConfigManager sharedManager].iCloudAvailable) {
    // 显示 iCloud 同步开关
    BOOL enabled = [MSTConfigManager sharedManager].iCloudSyncEnabled;
    // 创建 UISwitch 或其他控件
}

// 切换 iCloud 同步
- (void)toggleiCloudSync:(UISwitch *)sender {
    [MSTConfigManager sharedManager].iCloudSyncEnabled = sender.on;
}
```

### 4. 测试（推荐）
测试步骤：
1. 在设备 A 上启用 iCloud 同步
2. 添加或修改一个 Host 配置
3. 在设备 B 上启用 iCloud 同步
4. 验证配置是否自动同步
5. 在设备 B 上修改配置
6. 验证设备 A 是否收到更新

## API 使用说明

### 启用/禁用 iCloud 同步
```objective-c
// 启用 iCloud 同步
[MSTConfigManager sharedManager].iCloudSyncEnabled = YES;

// 禁用 iCloud 同步
[MSTConfigManager sharedManager].iCloudSyncEnabled = NO;

// 检查 iCloud 是否可用
BOOL available = [MSTConfigManager sharedManager].iCloudAvailable;
```

### 监听配置变化
```objective-c
// 监听配置变化通知（包括来自 iCloud 的变化）
[[NSNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(configDidChange:)
           name:MSTConfigDidChangeNotification
         object:nil];
```

## 注意事项

1. **iCloud 账户**：用户必须登录 iCloud 账户才能使用同步功能
2. **网络连接**：同步需要网络连接，离线时会在恢复网络后自动同步
3. **存储限制**：NSUbiquitousKeyValueStore 有 1MB 的存储限制，适合轻量级配置
4. **冲突处理**：系统会自动使用最新的数据，采用"最后写入胜出"策略
5. **隐私**：敏感信息（如 AccessKey、SecretKey）会随配置同步，确保用户了解这一点

## 实现细节

### 数据存储
- **本地存储**：`NSUserDefaults` (App Group)
- **云端存储**：`NSUbiquitousKeyValueStore`
- **同步策略**：本地优先，云端备份

### 同步时机
1. **保存时**：每次调用 `saveConfigs` 时自动同步到 iCloud
2. **启动时**：如果启用 iCloud 同步，优先从云端加载
3. **外部变化时**：监听 `NSUbiquitousKeyValueStoreDidChangeExternallyNotification`

### 冲突解决
- 使用云端数据覆盖本地数据（最后写入胜出）
- 自动合并不会造成数据丢失
- 建议提示用户有新数据从 iCloud 同步

## 故障排查

### iCloud 不可用
检查：
1. 用户是否登录 iCloud
2. 应用是否有 iCloud 权限
3. Xcode 项目是否正确配置 iCloud capability

### 数据未同步
检查：
1. `iCloudSyncEnabled` 是否为 YES
2. 网络连接是否正常
3. 查看控制台日志中的错误信息

### 配额超限
如果遇到 `NSUbiquitousKeyValueStoreQuotaViolationChange` 错误：
- 检查存储的数据大小
- 考虑减少同步的数据量
- 或改用 iCloud Documents 或 CloudKit
