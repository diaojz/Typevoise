#!/bin/bash

# Typevoise 打包和安装脚本
# 用途: 构建 Release 版本并安装到 /Applications 目录

set -e  # 遇到错误立即退出

# 颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}开始构建 Typevoise Release 版本...${NC}"

# 获取脚本所在目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# 清理旧的构建产物
rm -rf ./build

# 构建 Release 版本,使用 ad-hoc 签名(本地使用)
xcodebuild -project Typevoise.xcodeproj \
  -scheme Typevoise \
  -configuration Release \
  -derivedDataPath ./build \
  CODE_SIGN_IDENTITY="-" \
  build

echo -e "${GREEN}✓ 构建成功${NC}"

# 检查构建产物
APP_PATH="./build/Build/Products/Release/Typevoise.app"
if [ ! -d "$APP_PATH" ]; then
    echo "错误: 找不到构建产物 $APP_PATH"
    exit 1
fi

echo -e "${BLUE}正在安装到 /Applications...${NC}"

# 删除旧版本(如果存在)
if [ -d "/Applications/Typevoise.app" ]; then
    rm -rf /Applications/Typevoise.app
    echo "已删除旧版本"
fi

# 复制到 Applications
cp -R "$APP_PATH" /Applications/

echo -e "${GREEN}✓ 安装完成${NC}"
echo ""
echo "Typevoise.app 已安装到 /Applications"
echo "现在可以:"
echo "  1. 从 Launchpad 或 Applications 文件夹启动 Typevoise"
echo "  2. 在 系统设置 → 隐私与安全性 → 辅助功能 中授予权限"
