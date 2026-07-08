#!/bin/bash
# tap-update-install.sh
# 自动更新 Homebrew Tap 并安装指定的 Formula
# 用法: ./tap-update-install.sh [选项] <package-name>
# 示例: ./tap-update-install.sh i386-jos-elf-gcc
#       ./tap-update-install.sh -s i386-jos-elf-gcc
#       ./tap-update-install.sh -n i386-jos-elf-gcc
#       ./tap-update-install.sh -s -n i386-jos-elf-gcc

set -e  # 遇到错误立即退出

# 关闭 Homebrew 自动更新
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_GITHUB_API=1

# 获取脚本绝对路径（跨平台）
get_script_path() {
    local script_path

    # 尝试 readlink -f（Linux）
    if command -v readlink &>/dev/null && readlink -f "$0" &>/dev/null; then
        script_path=$(readlink -f "$0")
    # 尝试 realpath（Linux）
    elif command -v realpath &>/dev/null; then
        script_path=$(realpath "$0")
    # 尝试 grealpath（macOS + coreutils）
    elif command -v grealpath &>/dev/null; then
        script_path=$(grealpath "$0")
    # 回退方案
    else
        script_path="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
    fi

    echo "$script_path"
}

# 使用
CURRENT_PATH=$PWD
SCRIPT_PATH=$(get_script_path)
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
SCRIPT_NAME=$(basename "$SCRIPT_PATH")

echo "当前路径：$CURRENT_PATH"
echo "脚本路径：$SCRIPT_PATH"
echo "脚本目录：$SCRIPT_DIR"
echo "脚本名称：$SCRIPT_NAME"

# 显示使用帮助
show_usage() {
    echo "用法: $0 [选项] <package-name>"
    echo ""
    echo "选项:"
    echo "  -s, --build-from-source  从源码编译安装（不使用 bottle）"
    echo "  -n, --dry-run            模拟运行，显示将要执行的命令但不实际执行"
    echo "  -h, --help               显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 i386-jos-elf-gcc              # 正常安装"
    echo "  $0 -s i386-jos-elf-gcc           # 从源码编译安装"
    echo "  $0 -n i386-jos-elf-gcc           # 模拟运行"
    echo "  $0 -s -n i386-jos-elf-gcc        # 模拟从源码编译安装"
    echo "  $0 elks                          # 安装 elks"
    echo "  $0 binutils                      # 安装 binutils"
    echo ""
    echo "说明:"
    echo "  该脚本会自动检测当前 Git 仓库的远程 URL，"
    echo "  进入对应的 Homebrew Tap 目录并更新，"
    echo "  然后安装指定的 Formula 包。"
}

# 初始化选项变量
BUILD_FROM_SOURCE=false
DRY_RUN=false
PACKAGE_NAME=""

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--build-from-source)
            BUILD_FROM_SOURCE=true
            shift
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        -*)
            echo "❌ 错误：未知选项 $1"
            show_usage
            exit 1
            ;;
        *)
            # 第一个非选项参数作为包名
            if [ -z "$PACKAGE_NAME" ]; then
                PACKAGE_NAME="$1"
                shift
            else
                echo "❌ 错误：只能指定一个包名"
                show_usage
                exit 1
            fi
            ;;
    esac
done

# 检查是否提供了包名参数
if [ -z "$PACKAGE_NAME" ]; then
    echo "❌ 错误：缺少包名参数"
    show_usage
    exit 1
fi

echo "📦 准备安装包：$PACKAGE_NAME"
echo "🔧 选项设置："
echo "  从源码编译: $BUILD_FROM_SOURCE"
echo "  模拟运行: $DRY_RUN"

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
    if [ "$DRY_RUN" = false ]; then
        brew tap "${USER_NAME_LOWER}/${TAP_NAME}"
    else
        echo "  [DRY RUN] brew tap ${USER_NAME_LOWER}/${TAP_NAME}"
    fi
else
    echo "✅ Tap 已存在，准备更新..."
fi

# 进入 Tap 目录并执行 git pull
if [ "$DRY_RUN" = false ]; then
    echo "🔄 进入 Tap 目录并更新..."
    cd "$TAP_PATH"

    # 调试 Git 相关环境变量（可选）
    # export GIT_CURL_VERBOSE=1
    # export GIT_TRACE=1
    # export GIT_SSH_COMMAND='ssh -vvv'

    git pull
    echo "✅ 更新完成"
else
    echo "  [DRY RUN] cd $TAP_PATH"
    echo "  [DRY RUN] git pull"
fi

# 构造完整的 Tap 引用：$user/$tap/$package
TAP_REF="${USER_NAME_LOWER}/${TAP_NAME}/${PACKAGE_NAME}"

# 检查 Formula 是否存在
if [ "$DRY_RUN" = false ]; then
    if brew info -v -d "$TAP_REF" &>/dev/null; then
        echo "📦 找到 Formula：$TAP_REF"
    else
        echo "❌ 错误：Formula '$TAP_REF' 不存在"
        echo "请检查包名是否正确，或确认该 Formula 是否在 Tap 中。"
        echo ""
        echo "可用的 Formula 列表："
        brew search "${USER_NAME_LOWER}/${TAP_NAME}/"
        exit 1
    fi
else
    echo "  [DRY RUN] brew info -v -d $TAP_REF"
fi

# 构建 brew install 命令
BREW_CMD="brew install"

# 添加选项
if [ "$BUILD_FROM_SOURCE" = true ]; then
    BREW_CMD="$BREW_CMD --build-from-source"
fi

# 添加调试选项（可以根据需要添加更多）
BREW_CMD="$BREW_CMD -v -d"

# 添加包名
BREW_CMD="$BREW_CMD $TAP_REF"

# 检查是否已安装
if [ "$DRY_RUN" = false ]; then
    if brew list -v -d "$TAP_REF" &>/dev/null; then
        echo "⏭️ Formula 已安装，直接退出..."
        # 如果需要升级，可以取消注释下行
        # brew upgrade "$TAP_REF"
        exit 0
    else
        echo "📦 即将执行：$BREW_CMD"
        eval "$BREW_CMD"
    fi
else
    echo "  [DRY RUN] 将执行：$BREW_CMD"
    echo "  [DRY RUN] 模拟运行完成（未实际执行）"
fi

if [ "$DRY_RUN" = false ]; then
    echo "✅ 安装完成！"
fi