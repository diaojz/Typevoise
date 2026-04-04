#!/bin/bash

# Typevoise 部署脚本
# 用途：构建 Release 版本并安装到 /Applications

set -e  # 遇到错误立即退出

echo "🚀 开始构建 Typevoise..."

# 构建 Release 版本
xcodebuild -project Typevoise.xcodeproj \
  -scheme Typevoise \
  -configuration Release \
  -derivedDataPath ./build \
  build

echo "✅ 构建成功"

# 删除旧版本
if [ -d "/Applications/Typevoise.app" ]; then
  echo "🗑️  删除旧版本..."
  rm -rf /Applications/Typevoise.app
fi

# 安装新版本
echo "📦 安装到 /Applications..."
cp -R ./build/Build/Products/Release/Typevoise.app /Applications/

echo "✅ 部署完成！"
echo "💡 提示：请重启 Typevoise 应用以使用新版本"
