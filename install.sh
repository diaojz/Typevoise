#!/bin/bash

# Typevoise 一键安装脚本
# 适用于完全不懂代码的用户

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# 打印欢迎信息
clear
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║              🎤 Typevoise 一键安装程序 🎤                  ║"
echo "║                                                            ║"
echo "║          语音转文字 + AI 润色 + 自动粘贴                   ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
print_info "本脚本将自动完成以下操作："
echo "  1. 检查系统环境"
echo "  2. 下载必要的组件"
echo "  3. 构建并安装应用"
echo "  4. 配置权限"
echo ""
read -p "按回车键开始安装..."

# 步骤 1: 检查系统
echo ""
print_info "步骤 1/4: 检查系统环境..."

# 检查 macOS 版本
macos_version=$(sw_vers -productVersion)
print_info "macOS 版本: $macos_version"

# 检查 Xcode Command Line Tools
if ! xcode-select -p &> /dev/null; then
    print_warning "未检测到 Xcode Command Line Tools"
    print_info "正在安装 Xcode Command Line Tools（这可能需要几分钟）..."
    xcode-select --install
    print_info "请在弹出的窗口中点击"安装"，完成后按回车继续..."
    read
fi

print_success "系统环境检查完成"

# 步骤 2: 初始化子模块
echo ""
print_info "步骤 2/4: 下载 Whisper 语音识别组件..."

if [ -d "whisper-service/.git" ]; then
    print_info "Whisper 组件已存在，跳过下载"
else
    print_info "正在下载 Whisper 组件（约 1MB）..."
    git submodule update --init --recursive
    print_success "Whisper 组件下载完成"
fi

# 步骤 3: 构建应用
echo ""
print_info "步骤 3/4: 构建 Typevoise 应用..."
print_info "这可能需要 1-2 分钟，请耐心等待..."

# 检查并终止正在运行的 Typevoise
if pgrep -x "Typevoise" > /dev/null; then
    print_info "检测到 Typevoise 正在运行，正在关闭..."
    pkill -x "Typevoise"
    sleep 1
fi

# 清理旧的构建
rm -rf ./build

# 构建 Release 版本
if xcodebuild -project Typevoise.xcodeproj \
  -scheme Typevoise \
  -configuration Release \
  -derivedDataPath ./build \
  build > /tmp/typevoise_build.log 2>&1; then
    print_success "应用构建成功"
else
    print_error "构建失败，请查看日志: /tmp/typevoise_build.log"
    exit 1
fi

# 步骤 4: 安装应用
echo ""
print_info "步骤 4/4: 安装到 /Applications..."

APP_PATH="./build/Build/Products/Release/Typevoise.app"
if [ ! -d "$APP_PATH" ]; then
    print_error "找不到构建产物"
    exit 1
fi

# 删除旧版本
if [ -d "/Applications/Typevoise.app" ]; then
    rm -rf /Applications/Typevoise.app
    print_info "已删除旧版本"
fi

# 复制到 Applications
cp -R "$APP_PATH" /Applications/
print_success "应用已安装到 /Applications"

# 完成
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║                  🎉 安装完成！🎉                           ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
print_success "Typevoise 已成功安装！"
echo ""
print_info "接下来的步骤："
echo ""
echo "  1️⃣  打开 Launchpad，找到并启动 Typevoise"
echo ""
echo "  2️⃣  首次启动时，需要授予以下权限："
echo "     • 麦克风权限（用于录音）"
echo "     • 语音识别权限（用于转文字）"
echo "     • 辅助功能权限（用于自动粘贴）"
echo ""
echo "  3️⃣  在设置中填入你的 Claude API Key"
echo ""
echo "  4️⃣  使用快捷键 ⌘⇧Space 开始语音输入"
echo ""
print_warning "重要提示："
echo "  辅助功能权限需要手动授予："
echo "  系统设置 → 隐私与安全性 → 辅助功能 → 添加 Typevoise"
echo ""
read -p "按回车键打开 Typevoise..."
open /Applications/Typevoise.app
echo ""
print_success "祝你使用愉快！"
echo ""
