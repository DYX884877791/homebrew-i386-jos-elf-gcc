#!/bin/bash
# tap-update-install.sh
# 自动更新 Homebrew Tap 并安装指定的 Formula
# 用法: ./tap-update-install.sh <package-name>
# 示例: ./tap-update-install.sh i386-jos-elf-gcc

set -e  # 遇到错误立即退出


# $ xcode-select -p
#/Users/strager/Applications/Xcode_8.3.3.app/Contents/Developer
#
#$ clang --version
#Apple LLVM version 8.1.0 (clang-802.0.42)
#Target: x86_64-apple-darwin16.7.0
#Thread model: posix
#InstalledDir: /Users/strager/Applications/Xcode_8.3.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin
#
#$ as --version
#Apple LLVM version 8.1.0 (clang-802.0.42)
#Target: x86_64-apple-darwin16.7.0
#Thread model: posix
#InstalledDir: /Users/strager/Applications/Xcode_8.3.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin
#
#$ ld -v
#@(#)PROGRAM:ld  PROJECT:ld64-278.4
#configured to support archs: armv6 armv7 armv7s arm64 i386 x86_64 x86_64h armv6m armv7k armv7m armv7em (tvOS)
#LTO support using: LLVM version 8.1.0, (clang-802.0.42)
#TAPI support using: Apple TAPI version 1.33.11

# 使用brew安装软件时，默认每次都会自动更新homebrew，显示
#Updating Homebrew...，网络状况不好或者没有换源的时候，很慢，会卡在这里许久不动。
# 可以关闭自动更新，在命令行执行：
export HOMEBREW_NO_AUTO_UPDATE=true

# 获取脚本绝对路径（跨平台）
get_script_path() {
    local script_path

    # 尝试 readlink -f（Linux）
    if command -v readlink &>/dev/null && readlink -f "$0" &>/dev/null; then
        # 能解析符号链接，得到最终的真实路径
        script_path=$(readlink -f "$0")
    # 尝试 realpath（Linux）
    elif command -v realpath &>/dev/null; then
        # 类似 readlink -f，能解析符号链接
        # 有些系统默认安装（Coreutils）
        # 注意：macOS 默认没有 realpath 命令，需要安装 coreutils：brew install coreutils
        script_path=$(realpath "$0")
    # 尝试 grealpath（macOS + coreutils）
    elif command -v grealpath &>/dev/null; then
        script_path=$(grealpath "$0")
    # 回退方案
    else
        # 兼容所有 POSIX Shell（sh、bash、zsh 等）
        # 不需要额外命令
        # 如果脚本通过符号链接执行，得到的是符号链接的路径，而非真实路径
        script_path="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
    fi

    echo "$script_path"
}

# 使用
CURRENT_PATH=$PWD
SCRIPT_PATH=$(get_script_path)
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
SCRIPT_NAME=$(basename "$SCRIPT_PATH")

# 如果需要引用同目录下的其他文件
# CONFIG_FILE="$SCRIPT_DIR/config.sh"
# if [ -f "$CONFIG_FILE" ]; then
#     source "$CONFIG_FILE"
# fi

echo "当前路径：$CURRENT_PATH"
echo "脚本路径：$SCRIPT_PATH"
echo "脚本目录：$SCRIPT_DIR"
echo "脚本名称：$SCRIPT_NAME"

# 显示使用帮助
show_usage() {
    echo "用法: $0 <package-name>"
    echo ""
    echo "示例:"
    echo "  $0 i386-jos-elf-gcc"
    echo "  $0 elks"
    echo "  $0 binutils"
    echo ""
    echo "说明:"
    echo "  该脚本会自动检测当前 Git 仓库的远程 URL，"
    echo "  进入对应的 Homebrew Tap 目录并更新，"
    echo "  然后安装指定的 Formula 包。"
}

# 检查是否提供了包名参数
if [ $# -eq 0 ]; then
    echo "❌ 错误：缺少包名参数"
    show_usage
    exit 1
fi

# 第一个参数为包名
PACKAGE_NAME="$1"

# 检查是否请求帮助
if [ "$PACKAGE_NAME" = "-h" ] || [ "$PACKAGE_NAME" = "--help" ]; then
    show_usage
    exit 0
fi

echo "📦 准备安装包：$PACKAGE_NAME"

# 获取当前仓库的远程 URL（第一行，fetch 地址）
REMOTE_URL=$(git remote -v | head -n1 | awk '{print $2}')

# 检查是否成功获取 URL
if [ -z "$REMOTE_URL" ]; then
    echo "❌ 错误：无法获取 git remote URL，请确保您在 Git 仓库中运行此脚本。"
    exit 1
fi

echo "📍 检测到远程仓库：$REMOTE_URL"

# 从 URL 提取用户名和仓库名（去掉 .git 后缀）
REPO_NAME=$(basename "$REMOTE_URL" .git)
USER_NAME=$(basename "$(dirname "$REMOTE_URL")")

# 转换为小写（Homebrew Tap 路径要求小写）
USER_NAME_LOWER=$(echo "$USER_NAME" | tr '[:upper:]' '[:lower:]')
REPO_NAME_LOWER=$(echo "$REPO_NAME" | tr '[:upper:]' '[:lower:]')

# 去掉 homebrew- 前缀（用于 brew tap）
TAP_NAME=$(echo "$REPO_NAME_LOWER" | sed 's/^homebrew-//')

# 拼接 Homebrew Tap 本地路径
TAP_PATH="/usr/local/Homebrew/Library/Taps/${USER_NAME_LOWER}/${REPO_NAME_LOWER}"

echo "📁 Tap 路径：$TAP_PATH"
echo "🔗 Tap 名称：${USER_NAME_LOWER}/${TAP_NAME}"

# 检查 Tap 目录是否存在，如果不存在则执行 brew tap
if [ ! -d "$TAP_PATH" ]; then
    echo "⚠️  Tap 不存在，正在执行 brew tap..."
    brew tap "${USER_NAME_LOWER}/${TAP_NAME}"
else
    echo "✅ Tap 已存在，准备更新..."
fi

# 进入 Tap 目录并执行 git pull
echo "🔄 进入 Tap 目录并更新..."
cd "$TAP_PATH"
#
#环境变量	              作用层级	              主要输出	                        适用场景
#GIT_TRACE=2	          Git 内部执行	          命令调用、子进程、环境变量	          调试 Git 内部逻辑、脚本、别名
#GIT_TRACE_PACKET=1	    Git 协议层	            Git 协议数据包（如 git</git>）	    调试 fetch/push 协议通信
#GIT_CURL_VERBOSE=1	    HTTP/HTTPS 传输层	    HTTP 请求/响应、SSL/TLS 握手	      调试网络问题、代理、证书
#
#GIT_TRACE=1：基本跟踪，显示 Git 执行的关键命令
#GIT_TRACE=2：详细跟踪，显示更多内部信息（包括子进程、环境变量等）
export GIT_CURL_VERBOSE=1
export GIT_TRACE=1
export GIT_SSH_COMMAND='ssh -vvv'
git pull

echo "✅ 更新完成"

# 构造完整的 Tap 引用：user/tap/package
TAP_REF="${USER_NAME_LOWER}/${TAP_NAME}/${PACKAGE_NAME}"

# 检查 Formula 是否存在
if brew info -v -d "$TAP_REF" &>/dev/null; then
    echo "📦 找到 Formula：$TAP_REF"
else
    echo "❌ 错误：Formula '$TAP_REF' 不存在"
    echo "请检查包名是否正确，或确认该 Formula 是否在 Tap 中。"
    echo ""
    echo "执行brew info -v -d ${TAP_REF}，结果如下："
    brew info -v -d "$TAP_REF"
    echo ""
    echo "可用的 Formula 列表："
    brew search "${USER_NAME_LOWER}/${TAP_NAME}/"
    exit 1
fi

# 安装 Formula（如果已安装则升级）
if brew list -v -d "$TAP_REF" &>/dev/null; then
    echo "⏭️ Formula 已安装，直接退出..."
    # brew upgrade "$TAP_REF"
    exit 1
else
    echo "📦 正在安装 $TAP_REF..."
    brew install -v -d "$TAP_REF"
fi

echo "✅ 安装完成！"