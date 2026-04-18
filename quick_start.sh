#!/bin/bash

# Whisper 集成快速启动脚本

set -e

echo "🚀 Whisper 集成快速启动"
echo "========================"
echo ""

# 1. 启动 Whisper 服务
echo "📦 步骤 1/3: 启动 Whisper 服务"
echo "位置: /Users/diaoye/Documents/BD/App Store/app/whisper-service"
echo ""
echo "请在新终端窗口运行："
echo "  cd \"/Users/diaoye/Documents/BD/App Store/app/whisper-service\""
echo "  ./start.sh"
echo ""
read -p "服务已启动？(y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ 请先启动服务"
    exit 1
fi

# 2. 验证服务
echo ""
echo "🔍 步骤 2/3: 验证服务状态"
if curl -s http://127.0.0.1:5001/health | grep -q "ok"; then
    echo "✅ Whisper 服务运行正常"
else
    echo "❌ Whisper 服务未响应"
    echo "请检查服务是否正常启动"
    exit 1
fi

# 3. 打开 Xcode 项目
echo ""
echo "📝 步骤 3/3: 打开 Xcode 项目"
echo ""
echo "需要手动添加以下文件到项目："
echo "  - Typevoise/Services/WhisperService.swift"
echo "  - Typevoise/Services/WhisperRecognizer.swift"
echo ""
echo "正在打开 Xcode..."
open "/Users/diaoye/Documents/BD/App Store/app/Typevoise/Typevoise.xcodeproj"

echo ""
echo "✨ 准备完成！"
echo ""
echo "下一步："
echo "1. 在 Xcode 中添加新文件（右键 Services 文件夹 → Add Files）"
echo "2. 构建并运行 App (⌘R)"
echo "3. 在设置中切换到 Whisper 引擎"
echo "4. 测试远距离识别效果"
echo ""
echo "详细步骤请查看: WHISPER_TEST_GUIDE.md"
