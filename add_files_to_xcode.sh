#!/bin/bash

# 将新文件添加到 Xcode 项目的脚本

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$SCRIPT_DIR"
cd "$PROJECT_DIR"

echo "📦 将新文件添加到 Xcode 项目..."

# 打开 Xcode 并添加文件
# 注意：这需要手动操作，或者使用 xcodebuild 命令

echo "
请在 Xcode 中手动添加以下文件：

1. Typevoise/Services/WhisperService.swift
2. Typevoise/Services/WhisperRecognizer.swift

步骤：
1. 打开 Typevoise.xcodeproj
2. 右键点击 Services 文件夹
3. 选择 'Add Files to \"Typevoise\"...'
4. 选择上述两个文件
5. 确保 'Copy items if needed' 未勾选（文件已在正确位置）
6. 确保 'Add to targets' 中 Typevoise 已勾选
7. 点击 Add

或者直接运行：
open \"$PROJECT_DIR/Typevoise.xcodeproj\"
"

# 自动打开 Xcode
open "$PROJECT_DIR/Typevoise.xcodeproj"
