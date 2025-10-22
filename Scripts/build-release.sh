#!/bin/bash

cd "$(dirname "$0")/.." || { echo "❌ 无法进入项目根目录"; exit 1; }

if [ -f "./CSUSTPlanetBackend" ]; then
    echo "🧹 正在删除旧的二进制文件..."
    rm -f ./CSUSTPlanetBackend
fi

case "$(uname -s)" in
  Linux*)
    echo "🐧 检测到 Linux 系统，正在构建静态链接的 Release 版本..."
    swift build -c release --static-swift-stdlib || { echo "❌ 构建失败"; exit 1; }
    ;;
  Darwin*)
    echo "🍎 检测到 macOS 系统，正在构建 Release 版本..."
    swift build -c release || { echo "❌ 构建失败"; exit 1; }
    ;;
  *)
    echo "⚠️  不支持的操作系统：$(uname -s)" >&2
    exit 1
    ;;
esac

echo "📦 正在复制可执行文件..."
cp .build/release/CSUSTPlanetBackend ./CSUSTPlanetBackend || { echo "❌ 复制可执行文件失败"; exit 1; }

chmod +x ./CSUSTPlanetBackend

echo "✅ 构建成功！二进制文件已生成：./CSUSTPlanetBackend"