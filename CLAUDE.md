# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

Typevoise 是一个 macOS 菜单栏应用,提供全局快捷键触发的语音转文字功能。

### 核心功能
- 系统级语音识别 (使用 Apple Speech Framework)
- 全局快捷键监听 (⌘⇧Space)
- 键盘模拟输入 (通过 CGEvent 实现自动粘贴)
- 菜单栏常驻

### 技术栈
- Swift + SwiftUI
- Speech Framework (语音识别)
- CoreGraphics (键盘模拟)
- AppKit (菜单栏和快捷键)

## 项目结构

```
Typevoise/
├── TypevoiseApp.swift          # 应用入口,管理生命周期
├── Models/
│   └── SpeechRecognizer.swift  # 语音识别核心逻辑
├── Services/
│   └── KeyboardSimulator.swift # 键盘事件模拟
├── Managers/
│   └── ShortcutManager.swift   # 全局快捷键管理
├── Views/
│   └── StatusBarView.swift     # 菜单栏 UI
├── Assets.xcassets/            # 应用图标
├── Typevoise.entitlements      # 权限配置
└── Info.plist                  # 应用配置
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

### 快速打包安装

使用提供的脚本:

```bash
./build_and_install.sh
```

### 手动构建命令

```bash
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
项目配置了自动签名 (`CODE_SIGN_STYLE = Automatic`),使用开发团队 `NG29L97GY7`。

### Sandbox 限制
应用运行在 App Sandbox 中,某些系统 API 可能受限。键盘模拟功能需要辅助功能权限才能工作。

### 快捷键冲突
默认快捷键是 ⌘⇧Space,可能与系统或其他应用冲突。如需修改,在 `ShortcutManager.swift` 中调整。

### 语音识别
使用系统内置的语音识别引擎,识别准确度取决于:
- 环境噪音
- 说话清晰度
- 系统语言设置

## 常见问题

### 辅助功能权限问题
**症状**: App 不出现在"系统设置 → 隐私与安全性 → 辅助功能"列表中

**解决方案**:
1. 不要直接从 Xcode 运行
2. 使用 `build_and_install.sh` 构建并安装 Release 版本
3. 从 `/Applications` 启动应用
4. 此时应该会出现在辅助功能列表中

### 快捷键不响应
检查是否已授予辅助功能权限。

### 语音识别失败
检查是否已授予麦克风和语音识别权限。

## 修改指南

### 修改快捷键
编辑 `Managers/ShortcutManager.swift`,修改 `keyCode` 和 `modifierFlags`。

### 修改 UI
编辑 `Views/StatusBarView.swift`,使用 SwiftUI 语法。

### 修改语音识别逻辑
编辑 `Models/SpeechRecognizer.swift`,调整识别参数或后处理逻辑。

### 添加新功能
遵循现有的 MVVM 架构:
- Models: 数据和业务逻辑
- Views: UI 组件
- Services: 系统服务封装
- Managers: 功能管理器

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

### App Store 发布
需要额外配置:
1. 配置 App Store Connect
2. 创建 Archive
3. 上传到 App Store
4. 提交审核

### 独立分发
可以直接分发 `.app` 文件,但用户需要:
1. 手动复制到 `/Applications`
2. 首次打开时右键选择"打开"(绕过 Gatekeeper)
3. 手动授予所有权限

## 相关文档

- [README.md](README.md): 用户使用文档
- [build_and_install.sh](build_and_install.sh): 自动化构建脚本
- [Apple Speech Framework](https://developer.apple.com/documentation/speech)
- [CGEvent Reference](https://developer.apple.com/documentation/coregraphics/cgevent)
