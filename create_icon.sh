#!/bin/bash

# 图标生成脚本
ICON_DIR="/Users/diaoye/Documents/BD/App Store/app/Typevoise/Typevoise/Assets.xcassets/AppIcon.appiconset"

# 使用 sips 和 SF Symbols 创建图标
# 这里我们使用渐变色背景 + 波形图标

# 创建一个临时的 1024x1024 图标
cat > /tmp/create_icon.swift << 'SWIFT'
import Cocoa
import AppKit

let size = CGSize(width: 1024, height: 1024)
let image = NSImage(size: size)

image.lockFocus()

// 绘制渐变背景
let gradient = NSGradient(colors: [
    NSColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0),  // 蓝色
    NSColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 1.0)   // 浅蓝色
])
gradient?.draw(in: NSRect(origin: .zero, size: size), angle: 135)

// 绘制圆角矩形边框
let borderPath = NSBezierPath(roundedRect: NSRect(x: 20, y: 20, width: 984, height: 984), xRadius: 180, yRadius: 180)
NSColor.white.withAlphaComponent(0.2).setStroke()
borderPath.lineWidth = 8
borderPath.stroke()

// 绘制波形符号
if let symbolImage = NSImage(systemSymbolName: "waveform", accessibilityDescription: nil) {
    let symbolConfig = NSImage.SymbolConfiguration(pointSize: 512, weight: .regular)
    let configuredSymbol = symbolImage.withSymbolConfiguration(symbolConfig)

    let symbolRect = NSRect(x: 256, y: 256, width: 512, height: 512)
    configuredSymbol?.draw(in: symbolRect, from: .zero, operation: .sourceOver, fraction: 1.0)
}

image.unlockFocus()

// 保存为 PNG
if let tiffData = image.tiffRepresentation,
   let bitmapImage = NSBitmapImageRep(data: tiffData),
   let pngData = bitmapImage.representation(using: .png, properties: [:]) {
    try? pngData.write(to: URL(fileURLWithPath: "/tmp/icon_1024.png"))
}

print("Icon created at /tmp/icon_1024.png")
SWIFT

# 编译并运行 Swift 脚本
swiftc -o /tmp/create_icon /tmp/create_icon.swift -framework Cocoa
/tmp/create_icon

# 生成各种尺寸
sips -z 16 16 /tmp/icon_1024.png --out "$ICON_DIR/icon_16x16.png"
sips -z 32 32 /tmp/icon_1024.png --out "$ICON_DIR/icon_16x16@2x.png"
sips -z 32 32 /tmp/icon_1024.png --out "$ICON_DIR/icon_32x32.png"
sips -z 64 64 /tmp/icon_1024.png --out "$ICON_DIR/icon_32x32@2x.png"
sips -z 128 128 /tmp/icon_1024.png --out "$ICON_DIR/icon_128x128.png"
sips -z 256 256 /tmp/icon_1024.png --out "$ICON_DIR/icon_128x128@2x.png"
sips -z 256 256 /tmp/icon_1024.png --out "$ICON_DIR/icon_256x256.png"
sips -z 512 512 /tmp/icon_1024.png --out "$ICON_DIR/icon_256x256@2x.png"
sips -z 512 512 /tmp/icon_1024.png --out "$ICON_DIR/icon_512x512.png"
sips -z 1024 1024 /tmp/icon_1024.png --out "$ICON_DIR/icon_512x512@2x.png"

echo "✅ 图标已生成"
