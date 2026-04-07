#!/bin/bash

# Typevoise 部署脚本
# 用途：清理旧构建、构建 Release 版本，并安装到 /Applications

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}开始构建 Typevoise Release 版本...${NC}"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

rm -rf ./build

xcodebuild -project Typevoise.xcodeproj \
  -scheme Typevoise \
  -configuration Release \
  -derivedDataPath ./build \
  build

echo -e "${GREEN}✓ 构建成功${NC}"

APP_PATH="./build/Build/Products/Release/Typevoise.app"
if [ ! -d "$APP_PATH" ]; then
    echo "错误: 找不到构建产物 $APP_PATH"
    exit 1
fi

echo -e "${BLUE}正在安装到 /Applications...${NC}"

if [ -d "/Applications/Typevoise.app" ]; then
    rm -rf /Applications/Typevoise.app
    echo "已删除旧版本"
fi

cp -R "$APP_PATH" /Applications/

echo -e "${GREEN}✓ 安装完成${NC}"
echo ""
echo "Typevoise.app 已安装到 /Applications"
echo "现在可以:"
echo "  1. 运行 ./deploy.sh 进行本地部署"
echo "  2. 从 Launchpad 或 Applications 文件夹启动 Typevoise"
echo "  3. 在 系统设置 → 隐私与安全性 → 辅助功能 中授予权限"
