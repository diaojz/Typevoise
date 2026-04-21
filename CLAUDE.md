# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

Typevoise 是一个 macOS 菜单栏应用,提供全局快捷键触发的语音转文字功能。

### 核心功能
- 系统级语音识别 (Apple Speech Framework)
- Whisper 本地识别（可选，通过 whisper-service 子模块）
- AI 智能润色（Claude API，支持多模型回退）
- 全局快捷键监听（可自定义）
- 自动粘贴到光标位置（CGEvent 模拟）
- 历史记录管理（持久化存储）
- 菜单栏常驻

### 技术栈
- Swift + SwiftUI
- Speech Framework（系统语音识别）
- faster-whisper（本地 Whisper 识别，Python 服务）
- Claude API（文本润色）
- CoreGraphics（键盘模拟）
- AppKit（菜单栏和快捷键）
- Carbon（全局热键注册）

## 项目结构

```
Typevoise/
├── TypevoiseApp.swift          # 应用入口
├── Models/
│   ├── SpeechRecognizer.swift  # 系统语音识别
│   ├── WhisperRecognizer.swift # Whisper 识别封装
│   ├── TranscriptionRecord.swift # 转写记录数据模型
│   ├── SettingsManager.swift   # 设置管理
│   └── KeyCodeMapper.swift     # 快捷键映射
├── Services/
│   ├── ClaudeService.swift     # Claude API 服务
│   ├── SpeechRecognizer.swift  # 语音识别服务
│   └── TextInserter.swift      # 文本插入服务
├── Managers/
│   ├── VoiceController.swift   # 语音控制器（主流程编排）
│   ├── HotkeyManager.swift     # 快捷键管理
│   ├── StatusBarController.swift # 状态栏控制器
│   ├── RecordingOverlayController.swift # 录音浮窗控制器
│   ├── HistoryManager.swift    # 历史记录管理
│   ├── WhisperServiceManager.swift # Whisper 服务管理
│   └── WhisperModelManager.swift # Whisper 模型管理
├── Views/
│   ├── ContentView.swift       # 主视图
│   ├── SettingsView.swift      # 设置视图
│   ├── HistoryView.swift       # 历史记录视图
│   ├── WelcomeView.swift       # 欢迎视图
│   ├── RecordingOverlayView.swift # 录音浮窗视图
│   └── HotkeyRecorderViewController.swift # 快捷键录制视图
├── Assets.xcassets/            # 应用图标和资源
├── Typevoise.entitlements      # 权限配置
└── Info.plist                  # 应用配置
```

## 依赖项目

### whisper-service（Git 子模块）

位于项目根目录的 `whisper-service/`，提供本地 Whisper 识别服务：
- Python Flask 服务器
- faster-whisper 模型
- 独立的 Git 仓库：https://github.com/diaojz/whisper-service

初始化子模块：
```bash
git submodule update --init --recursive
```

## 权限配置

### Entitlements (Typevoise.entitlements)
- `com.apple.security.app-sandbox`: App Sandbox
- `com.apple.security.device.microphone`: 麦克风访问
- `com.apple.security.personal-information.speech-recognition`: 语音识别
- `com.apple.security.files.user-selected.read-only`: 文件读取

### Info.plist 权限说明
- `NSMicrophoneUsageDescription`: 麦克风权限说明
- `NSSpeechRecognitionUsageDescription`: 语音识别权限说明
- `LSUIElement`: 隐藏 Dock 图标,仅显示菜单栏

### 辅助功能权限
应用需要辅助功能权限来模拟键盘输入。这个权限需要用户在系统设置中手动授予。

**重要**: 通过 Xcode 直接运行的 Debug 版本可能不会出现在"辅助功能"列表中。必须构建 Release 版本并安装到 `/Applications` 目录。

## 构建和打包

### 方式 1: 使用预编译版本（推荐）

从 [Releases 页面](https://github.com/diaojz/Typevoise/releases) 下载最新的 DMG 文件。

### 方式 2: 一键安装脚本

```bash
# 初始化子模块
git submodule update --init --recursive

# 运行安装脚本
./install.sh
```

脚本会自动：
1. 检查 Xcode Command Line Tools
2. 初始化 whisper-service 子模块
3. 构建 Release 版本
4. 安装到 `/Applications`

### 方式 3: 快速部署脚本

```bash
./deploy.sh
```

仅构建和安装，不检查环境。

### 手动构建命令

```bash
# 初始化子模块（首次）
git submodule update --init --recursive

# 构建 Release 版本
xcodebuild -project Typevoise.xcodeproj \
  -scheme Typevoise \
  -configuration Release \
  -derivedDataPath ./build \
  build

# 安装到 Applications
rm -rf /Applications/Typevoise.app
cp -R ./build/Build/Products/Release/Typevoise.app /Applications/
```

### 构建产物位置

- Release App: `./build/Build/Products/Release/Typevoise.app`
- Debug Symbols: `./build/Build/Products/Release/Typevoise.app.dSYM`

### 清理构建产物

```bash
rm -rf build/
```

## 开发注意事项

### 代码签名
项目配置了自动签名 (`CODE_SIGN_STYLE = Automatic`)。

### Sandbox 限制
应用运行在 App Sandbox 中，键盘模拟功能需要辅助功能权限。

### 快捷键冲突
默认快捷键是 ⌘⇧Space，可在设置中自定义。

### 语音识别
- 系统引擎：依赖环境噪音、说话清晰度、系统语言设置
- Whisper 引擎：需要启动 Python 服务，首次使用会下载模型

### 路径解析
代码中使用动态路径解析，避免硬编码绝对路径：
- 开发环境：从 Bundle 路径向上查找 whisper-service
- 生产环境：从 Bundle.main.resourcePath 查找

### Claude API
支持多模型回退和多种鉴权方式：
- 模型：claude-opus-4-6 → claude-sonnet-4-6 → claude-3-5-sonnet-latest
- 鉴权：Bearer → x-api-key

## 常见问题

### 辅助功能权限问题
**症状**: App 不出现在"系统设置 → 隐私与安全性 → 辅助功能"列表中

**解决方案**:
1. 不要直接从 Xcode 运行
2. 使用 `./deploy.sh` 构建并安装 Release 版本
3. 从 `/Applications` 启动应用
4. 此时应该会出现在辅助功能列表中

### 快捷键不响应
检查辅助功能权限：系统设置 → 隐私与安全性 → 辅助功能。

### 语音识别失败
1. 检查麦克风和语音识别权限
2. 尝试切换识别引擎（系统 ↔ Whisper）
3. 如果使用 Whisper，检查服务是否启动

### Whisper 服务问题
1. 检查 whisper-service 子模块是否初始化
2. 检查 Python 虚拟环境是否正确
3. 查看日志：`whisper-service/whisper.log`

### Claude API 调用失败
1. 检查 API Key 和 Base URL
2. 检查网络连接
3. 查看控制台日志了解具体错误

## 修改指南

### 修改快捷键
编辑 `Managers/HotkeyManager.swift`，或在应用设置中自定义。

### 修改 UI
- 主界面：`Views/ContentView.swift`
- 录音浮窗：`Views/RecordingOverlayView.swift`
- 设置界面：`Views/SettingsView.swift`

### 修改语音识别逻辑
- 系统引擎：`Models/SpeechRecognizer.swift`
- Whisper 引擎：`Models/WhisperRecognizer.swift`
- 流程控制：`Managers/VoiceController.swift`

### 修改 Claude 润色逻辑
编辑 `Services/ClaudeService.swift`，调整 prompt 或模型选择策略。

### 添加新功能
遵循现有架构：
- Models：数据模型和业务逻辑
- Views：SwiftUI 视图组件
- Services：外部服务封装（API、系统服务）
- Managers：功能管理器（状态管理、流程编排）

## 测试

### 手动测试流程
1. 构建并安装 Release 版本
2. 授予所有必要权限
3. 测试快捷键触发
4. 测试语音识别
5. 测试自动粘贴功能

### 调试技巧
- 使用 `print()` 输出日志
- 在 Xcode Console 查看语音识别状态
- 检查系统日志: `log stream --predicate 'process == "Typevoise"'`

## 发布

### GitHub Releases（推荐）

当前发布方式：https://github.com/diaojz/Typevoise/releases

构建 DMG：
1. 使用 `./deploy.sh` 构建 Release 版本
2. 使用 macOS 磁盘工具创建 DMG
3. 上传到 GitHub Releases

### App Store 发布（未来）

需要额外配置：
1. 配置 App Store Connect
2. 创建 Archive
3. 上传到 App Store
4. 提交审核

### 独立分发

直接分发 `.app` 或 `.dmg` 文件，用户需要：
1. 右键选择"打开"（绕过 Gatekeeper）
2. 手动授予所有权限

## 相关文档

- [README.md](README.md)：用户使用文档
- [GitHub Releases](https://github.com/diaojz/Typevoise/releases)：下载预编译版本
- [whisper-service](https://github.com/diaojz/whisper-service)：Whisper 服务子模块
- [install.sh](install.sh)：一键安装脚本
- [deploy.sh](deploy.sh)：快速部署脚本
- [Apple Speech Framework](https://developer.apple.com/documentation/speech)
- [CGEvent Reference](https://developer.apple.com/documentation/coregraphics/cgevent)
