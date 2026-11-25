#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "=== Search 1.0.19 简体中文版一键编译脚本 (Apple Silicon / arm64) ==="

if ! command -v swift >/dev/null 2>&1; then
  echo "错误：未检测到 Swift / Xcode 工具链。请先安装 Xcode 16+，或使用仓库中的 GitHub Actions 云端打包。" >&2
  exit 1
fi

echo "检测到 Swift 版本：$(swift --version | head -n 1)"
echo "开始编译 Search.app (arm64 Release)..."
SEARCH_ARCH=arm64 ./build.sh release app

echo ""
echo "✅ 编译完成！应用位于：$PWD/build/Search.app"
echo "提示："
echo "  1. 将 build/Search.app 拖入「应用程序」文件夹即可使用。"
echo "  2. 首次打开请右键点击 Search.app -> 选择「打开」（自编译未公证应用需手动放行一次）。"
echo "  3. 建议在「设置 › 关于」中关闭「自动安装更新」，避免被官方英文版覆盖。"
open "$PWD/build"
