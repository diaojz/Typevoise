# Typevoise

一个 macOS 菜单栏应用,通过快捷键快速进行语音转文字。

## 功能特性

- 🎤 系统级语音识别
- ✨ AI 智能润色（使用 Claude API）
- ⌨️ 全局快捷键触发（可自定义）
- 📋 自动粘贴识别结果到当前应用
- 📝 历史记录管理（查看、搜索、复制所有转写记录）
- 🔒 隐私安全，所有处理在本地完成

## 系统要求

- macOS 13.0 或更高版本
- 麦克风权限
- 语音识别权限
- 辅助功能权限

## 开发环境

- Xcode 15.0+
- Swift 5.9+

## 构建和安装

### 方式 1: 使用脚本(推荐)

```bash
./build_and_install.sh
```

这个脚本会:
1. 构建 Release 版本
2. 自动安装到 `/Applications` 目录
3. 清理旧版本

### 方式 2: 手动构建

```bash
# 构建 Release 版本
xcodebuild -project Typevoise.xcodeproj \
  -scheme Typevoise \
  -configuration Release \
  -derivedDataPath ./build \
  build

# 安装到 Applications
cp -R ./build/Build/Products/Release/Typevoise.app /Applications/
```

### 方式 3: 使用 Xcode

1. 在 Xcode 中打开 `Typevoise.xcodeproj`
2. 选择 Product → Archive
3. 在 Organizer 中选择 "Distribute App" → "Copy App"
4. 将导出的 App 复制到 `/Applications`

## 首次使用

1. 从 Launchpad 或 Applications 文件夹启动 Typevoise
2. 授予必要的权限:
   - 麦克风权限
   - 语音识别权限
   - **辅助功能权限**(在 系统设置 → 隐私与安全性 → 辅助功能 中手动添加)
3. 使用快捷键 ⌘⇧Space 开始语音输入

## 使用说明

### 语音转文字
1. 按下快捷键（默认 ⌘⇧Space，可在设置中自定义）
2. 开始说话
3. 再次按下快捷键停止录音
4. 识别的文字会经过 AI 润色后自动粘贴到当前光标位置

### 查看历史记录
1. 点击主界面的"历史记录"按钮
2. 在历史记录窗口中可以：
   - 查看所有转写记录（包括原文和润色后的文本）
   - 搜索历史记录
   - 复制原文或润色文本
   - 删除单条记录或清空所有记录

### 配置 Claude API
1. 点击主界面的"设置"按钮
2. 填入 Claude API Key 和 Base URL
3. 保存设置后即可使用 AI 润色功能

## 项目结构

```
Typevoise/
├── TypevoiseApp.swift          # 应用入口
├── Models/
│   ├── SpeechRecognizer.swift  # 语音识别核心
│   ├── TranscriptionRecord.swift # 转写记录数据模型
│   ├── SettingsManager.swift   # 设置管理
│   └── KeyCodeMapper.swift     # 快捷键映射
├── Services/
│   ├── ClaudeService.swift     # Claude API 服务
│   ├── SpeechRecognizer.swift  # 语音识别服务
│   └── TextInserter.swift      # 文本插入服务
├── Managers/
│   ├── VoiceController.swift   # 语音控制器
│   ├── HotkeyManager.swift     # 快捷键管理
│   ├── StatusBarController.swift # 状态栏控制器
│   ├── RecordingOverlayController.swift # 录音浮窗控制器
│   └── HistoryManager.swift    # 历史记录管理
├── Views/
│   ├── ContentView.swift       # 主视图
│   ├── SettingsView.swift      # 设置视图
│   ├── HistoryView.swift       # 历史记录视图
│   ├── WelcomeView.swift       # 欢迎视图
│   ├── RecordingOverlayView.swift # 录音浮窗视图
│   └── HotkeyRecorderViewController.swift # 快捷键录制视图
└── Assets.xcassets/            # 应用图标和资源
```

## 权限说明

### 麦克风权限
用于录制语音输入。

### 语音识别权限
用于将语音转换为文字。

### 辅助功能权限
用于模拟键盘输入,将识别的文字粘贴到当前应用。

**注意**: 辅助功能权限需要在系统设置中手动授予。通过 Xcode 直接运行的 Debug 版本可能不会出现在辅助功能列表中,需要安装 Release 版本到 `/Applications` 目录。

## 故障排除

### App 不出现在辅助功能列表中

确保你安装的是 Release 版本到 `/Applications` 目录,而不是直接从 Xcode 运行。使用 `build_and_install.sh` 脚本可以解决这个问题。

### 快捷键不工作

检查是否已授予辅助功能权限。

### 语音识别不准确

确保在安静的环境中使用,并清晰地说话。

## 开发

### 调试

```bash
# 在 Xcode 中运行
open Typevoise.xcodeproj
# 然后按 ⌘R 运行
```

### 清理构建产物

```bash
rm -rf build/
```

## 许可证

MIT License

## 作者

课程示例项目
