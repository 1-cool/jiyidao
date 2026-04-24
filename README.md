# 记忆岛

把取件码、取餐码、登机口等临时信息"钉"在通知栏上，像记忆一样常驻。

## 功能特性

- ✅ **短信自动识别** - 收到取件短信自动识别并添加
- ✅ **通知栏常驻** - 取件码固定在通知栏，随时可见，点击不消失
- ✅ **剪贴板识别** - 复制取件码自动识别
- ✅ **手动添加** - 支持手动输入取件码
- ✅ **滑动操作** - 左滑标记已取/删除
- ✅ **详情弹窗** - 点击查看详细信息，大字显示取件码
- ✅ **取快递提醒** - 定时提醒取快递，仅当有待取快递时提醒
- ✅ **暗黑模式** - 支持深蓝黑主题，可跟随系统或手动切换
- ✅ **Android 16 灵动岛** - 使用官方 Live Updates API（ProgressStyle）

## 支持的取件码格式

### 快递类
- 菜鸟驿站：`取件码：12-3-4567`
- 丰巢快递柜：`取件码 123456`
- 申通快递：`请凭0706-0331到XX领取`
- 通用格式：`取件码：123456`

### 外卖类
- 美团外卖：`取餐码：123`
- 饿了么：`取餐码：456`

### 出行类
- 登机口：`登机口：A12`
- 座位号：`座位：12A`

## 技术架构

### 架构设计

```
┌─────────────────────────────────────────────────────────────┐
│                        用户界面层                            │
│  HomeScreen / AddCodeScreen / SettingsScreen                │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                        业务逻辑层                            │
│  CodeManager (状态管理 + 数据操作)                           │
│  PatternMatcher (正则匹配 - 统一在 Flutter 端处理)           │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                        服务层                                │
│  NotificationService (通知 + 定时提醒)                       │
│  OppoIslandService (灵动岛)                                  │
│  SmsListenerService (短信监听)                               │
│  DatabaseService (SQLite 存储)                               │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                        原生层 (Android)                      │
│  MainActivity (短信广播监听 → 传递原始内容给 Flutter)         │
│  OppoIslandPlugin (ProgressStyle API)                       │
└─────────────────────────────────────────────────────────────┘
```

### 核心设计原则

1. **单一职责**：每个服务只负责一件事
2. **统一处理**：正则匹配统一在 Flutter 端的 `PatternMatcher` 处理，原生层只负责监听和传递
3. **系统级提醒**：定时提醒使用 `flutter_local_notifications` 的 `zonedSchedule`，App 被杀也能触发

### Flutter 端

| 模块 | 文件 | 说明 |
|------|------|------|
| 入口 | `lib/main.dart` | 应用初始化、Provider 注入 |
| 状态管理 | `lib/services/code_manager.dart` | 取件码业务逻辑、增删改查 |
| 数据模型 | `lib/models/code_item.dart` | 取件码数据结构 |
| 数据库 | `lib/services/database_service.dart` | SQLite 存储 |
| 正则匹配 | `lib/services/pattern_matcher.dart` | 短信内容识别引擎（统一处理） |
| 通知服务 | `lib/services/notification_service.dart` | 通知管理 + 定时提醒 |
| 灵动岛服务 | `lib/services/oppo_island_service.dart` | MethodChannel 通信 |
| 短信监听 | `lib/services/sms_listener_service.dart` | 接收原生层短信事件 |
| 主题管理 | `lib/theme/theme_manager.dart` | 深色/浅色模式切换 |

### Android 原生端

| 模块 | 文件 | 说明 |
|------|------|------|
| 主活动 | `MainActivity.kt` | 短信广播监听 + 插件注册 |
| 灵动岛插件 | `OppoIslandPlugin.kt` | Android 16 ProgressStyle API 实现 |

### 技术栈

- **UI 框架**: Flutter 3.5+ (Dart)
- **状态管理**: Provider
- **本地存储**: SQLite (sqflite)
- **通知**: flutter_local_notifications 21.0+
- **定时提醒**: timezone + zonedSchedule
- **权限管理**: permission_handler
- **Android API**: Notification.ProgressStyle (Android 16+)

## 灵动岛实现

### Android 16 Live Updates API

Android 16（API 35）引入了官方的 `Notification.ProgressStyle` API，用于创建以进度为中心的实时活动通知。记忆岛已完整适配此 API：

```kotlin
// ProgressStyle 示例
val progressStyle = Notification.ProgressStyle()
    .setStyledByProgress(false)
    .setProgress(100)
    .setProgressTrackerIcon(trackerIcon)
    .setProgressSegments(progressSegments)
    .setProgressPoints(progressPoints)

Notification.Builder(context, channelId)
    .setStyle(progressStyle)
    .setContentTitle("驿站名称")
    .setContentText("取件码")
    .build()
```

### 设备兼容性

| 设备 | 系统版本 | 支持状态 |
|------|---------|---------|
| Android 16+ 设备 | API 35+ | ✅ 完整支持 ProgressStyle |
| OPPO/一加/realme | ColorOS 16+ | ✅ 自动适配流体云 |
| Android 14-15 | API 33-34 | ⚠️ 降级为高优先级常驻通知 |
| Android 13 及以下 | API ≤32 | ⚠️ 降级为普通常驻通知 |

## 权限说明

| 权限 | 用途 |
|-----|------|
| RECEIVE_SMS | 接收短信广播，自动识别取件码 |
| POST_NOTIFICATIONS | 显示通知（Android 13+） |
| SCHEDULE_EXACT_ALARM | 定时提醒功能（Android 12+） |

## 版本历史

| 版本 | 说明 |
|------|------|
| v1.0.49-beta | 架构重构：统一正则匹配、简化通知系统、修复单例 Bug |
| v1.0.48-beta | Android 16 Live Updates API 完整实现 |
| v1.0.35-beta | 通知显示优化、日志功能 |
| v1.0.32-beta | 支持 realme 设备检测 |
| v1.0.29 | 稳定版，基础功能 |

## 项目结构

```
memory-island-flutter/
├── lib/
│   ├── main.dart                 # 应用入口
│   ├── models/
│   │   └── code_item.dart        # 数据模型
│   ├── screens/
│   │   ├── home_screen.dart      # 主页
│   │   ├── add_code_screen.dart  # 添加页面
│   │   ├── settings_screen.dart  # 设置页面
│   │   └── island_log_screen.dart # 灵动岛日志
│   ├── services/
│   │   ├── code_manager.dart     # 业务逻辑
│   │   ├── database_service.dart # 数据库
│   │   ├── notification_service.dart # 通知 + 定时提醒
│   │   ├── oppo_island_service.dart  # 灵动岛
│   │   ├── pattern_matcher.dart  # 正则匹配（统一处理）
│   │   └── sms_listener_service.dart # 短信监听
│   ├── theme/
│   │   ├── app_theme.dart        # 主题定义
│   │   └── theme_manager.dart    # 主题管理
│   └── widgets/                  # UI 组件
├── android/
│   └ app/src/main/kotlin/com/pincode/app/
│   │   ├── OppoIslandPlugin.kt   # 灵动岛原生实现
│   │   └── MainActivity.kt       # 主活动 + 短信监听
│   └ app/src/main/AndroidManifest.xml
├── pubspec.yaml                  # Flutter 依赖配置
└── README.md
```

## 开发计划

- [ ] iOS 支持
- [x] Android 灵动岛（Android 16 ProgressStyle API）
- [ ] 华为胶囊通知（HarmonyOS API）
- [ ] 小米超级岛（HyperOS API）
- [ ] 云端同步
- [ ] 智能提醒（位置触发）

## License

MIT
