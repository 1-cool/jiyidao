# 码钉 - GitHub Actions 自动构建指南

## 快速开始

### 方法一：Fork 后自动构建

1. **Fork 本项目到你的 GitHub 账号**
   
2. **启用 GitHub Actions**
   - 进入你的仓库 → Settings → Actions → General
   - 选择 "Allow all actions and reusable workflows"
   - 保存

3. **触发构建**
   - 方式 A：修改任意文件并推送到 main 分支
   - 方式 B：进入 Actions 页面，手动点击 "Run workflow"

4. **下载 APK**
   - 构建完成后，进入 Actions → 对应的 workflow run
   - 在页面底部的 "Artifacts" 区域下载 `pincode-app-release`

---

### 方法二：创建新仓库

```bash
# 1. 在 GitHub 创建新仓库（不要初始化 README）

# 2. 在本地初始化并推送
cd /path/to/flutter-project
git init
git add .
git commit -m "Initial commit: 码钉 App"
git branch -M main
git remote add origin https://github.com/你的用户名/你的仓库名.git
git push -u origin main

# 3. 等待 GitHub Actions 自动构建完成
```

---

### 方法三：发布正式版本

```bash
# 创建 tag 触发 Release 构建
git tag v1.0.0
git push origin v1.0.0

# GitHub Actions 会自动：
# 1. 构建 APK
# 2. 创建 GitHub Release
# 3. 上传 APK 到 Release 页面
```

---

## 构建产物

| 文件 | 说明 |
|-----|------|
| `app-release.apk` | Release 版本 APK，可直接安装 |
| 构建时间 | 约 5-10 分钟 |
| 保留时间 | 30 天 |

---

## 自定义配置

### 修改应用名称

编辑 `android/app/src/main/AndroidManifest.xml`:
```xml
<application android:label="你的应用名称" ...>
```

### 修改应用 ID

编辑 `android/app/build.gradle`:
```gradle
applicationId "com.yourcompany.yourapp"
```

### 修改版本号

编辑 `pubspec.yaml`:
```yaml
version: 1.0.0+1  # 格式: 版本名+构建号
```

---

## 常见问题

### Q: 构建失败怎么办？

1. 查看 Actions 页面的错误日志
2. 常见原因：
   - 依赖版本冲突 → 检查 `pubspec.yaml`
   - 代码语法错误 → 运行 `flutter analyze`
   - Android 配置错误 → 检查 `AndroidManifest.xml`

### Q: 如何添加签名？

1. 生成签名密钥：
```bash
keytool -genkey -v -keystore release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias pincode
```

2. 配置 GitHub Secrets：
   - `KEYSTORE_BASE64`: 密钥文件的 base64 编码
   - `KEYSTORE_PASSWORD`: 密钥库密码
   - `KEY_ALIAS`: 密钥别名
   - `KEY_PASSWORD`: 密钥密码

3. 修改 `build.yml` 添加签名步骤（需要额外配置）

### Q: 如何减少构建时间？

- 使用 `cache: true`（已配置）
- 减少依赖数量
- 使用更快的 runner（如 self-hosted）

---

## 项目结构

```
flutter-project/
├── .github/
│   └── workflows/
│       └── build.yml        # GitHub Actions 配置
├── lib/
│   ├── main.dart
│   ├── models/
│   ├── services/
│   ├── screens/
│   └── widgets/
├── android/
│   └── app/src/main/
│       ├── AndroidManifest.xml
│       └── kotlin/
├── pubspec.yaml
└── README.md
```

---

## 相关链接

- [Flutter 官方文档](https://docs.flutter.dev/)
- [GitHub Actions 文档](https://docs.github.com/en/actions)
- [Flutter Actions 示例](https://github.com/subosito/flutter-action)
