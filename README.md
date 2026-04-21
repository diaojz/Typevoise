# Typevoise

一个 macOS 菜单栏应用,通过快捷键快速进行语音转文字。

## 功能特性

- 🎤 系统级语音识别 + Whisper 本地识别（可选）
- ✨ AI 智能润色（使用 Claude API）
- ⌨️ 全局快捷键触发（可自定义）
- 📋 自动粘贴识别结果到当前应用
- 📝 历史记录管理（查看、搜索、复制所有转写记录）
- 🔒 隐私安全，所有处理在本地完成

## 安装方式

### 方式 1: 下载预编译版本（推荐，最简单）

**适合所有用户，无需任何开发工具：**

1. 访问 [Releases 页面](https://github.com/diaojz/Typevoise/releases)
2. 下载最新版本的 `.dmg` 文件
3. 双击打开 DMG 文件
4. 将 Typevoise 拖到 Applications 文件夹
5. 从 Launchpad 或 Applications 启动应用

就这么简单！🎉

### 方式 2: 一键安装脚本（从源码构建）

**适合想从源码构建的用户：**

1. 下载项目：
   - 访问 https://github.com/diaojz/Typevoise
   - 点击绿色的 "Code" 按钮
   - 选择 "Download ZIP"
   - 解压下载的文件

2. 打开终端（Terminal）：
   - 按 ⌘+空格，输入 "终端" 或 "Terminal"
   - 回车打开

3. 在终端中输入以下命令（复制粘贴即可）：
   ```bash
   cd ~/Downloads/Typevoise-main
   ./install.sh
   ```

4. 按照屏幕提示完成安装

## 系统要求

- macOS 13.0 或更高版本
- 麦克风权限
- 语音识别权限
- 辅助功能权限

## 开发环境

- Xcode 15.0+
- Swift 5.9+

### 方式 3: 开发者手动构建

**适合开发者，需要 Xcode：**

#### 使用自动化脚本

```bash
# 克隆主仓库
git clone https://github.com/diaojz/Typevoise.git
cd Typevoise

# 初始化子模块（包含 whisper-service）
git submodule update --init --recursive

# 方式 A: 一键构建安装
./install.sh

# 方式 B: 快速部署（仅构建和安装，不检查环境）
./deploy.sh
```

`deploy.sh` 脚本会:
1. 构建 Release 版本
2. 自动安装到 `/Applications` 目录
3. 清理旧版本

#### 手动构建

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

#### 使用 Xcode

1. 在 Xcode 中打开 `Typevoise.xcodeproj`
2. 选择 Product → Archive
3. 在 Organizer 中选择 "Distribute App" → "Copy App"
4. 将导出的 App 复制到 `/Applications`

## 首次使用

1. 启动 Typevoise
   - 从 Launchpad 或 Applications 文件夹启动
   - 如果提示"无法打开"，右键点击应用选择"打开"

2. 授予必要的权限:
   - **麦克风权限**（用于录音）
   - **语音识别权限**（用于转文字）
   - **辅助功能权限**（用于自动粘贴）
     - 在 系统设置 → 隐私与安全性 → 辅助功能 中手动添加 Typevoise

3. 配置 Claude API（可选，用于 AI 润色）
   - 点击菜单栏图标 → 设置
   - 填入 Claude API Key 和 Base URL
   - 如果不配置，将直接输出识别的原始文本

4. 使用快捷键 ⌘⇧Space 开始语音输入

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

### 无法打开应用（提示"已损坏"或"无法验证开发者"）

这是 macOS 的安全机制。解决方法：
1. 右键点击 Typevoise.app
2. 选择"打开"
3. 在弹出的对话框中点击"打开"

或者在终端中运行：
```bash
xattr -cr /Applications/Typevoise.app
```

### App 不出现在辅助功能列表中

确保你安装的是 Release 版本到 `/Applications` 目录。如果从源码构建，使用 `./deploy.sh` 或 `./install.sh` 脚本。

### 快捷键不工作

检查是否已授予辅助功能权限：
- 系统设置 → 隐私与安全性 → 辅助功能
- 确保 Typevoise 在列表中且已勾选

### 语音识别不准确

1. 确保在安静的环境中使用
2. 清晰地说话，不要太快
3. 可以尝试切换到 Whisper 引擎（在设置中）

### Claude API 调用失败

1. 检查 API Key 是否正确
2. 检查 Base URL 是否正确（默认：https://api.anthropic.com）
3. 检查网络连接
4. 如果使用代理，确保代理配置正确

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

## 更新日志

查看 [Releases 页面](https://github.com/diaojz/Typevoise/releases) 了解最新版本和更新内容。

## 反馈与贡献

- 问题反馈：[GitHub Issues](https://github.com/diaojz/Typevoise/issues)
- 功能建议：[GitHub Discussions](https://github.com/diaojz/Typevoise/discussions)
- 贡献代码：欢迎提交 Pull Request

## 许可证

MIT License

## 作者

课程示例项目
