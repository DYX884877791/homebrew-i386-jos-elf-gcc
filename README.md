# i386-jos-elf-gcc

1. `brew tap DYX884877791/i386-jos-elf-gcc`
2. `brew install -d -v i386-jos-elf-gcc`
3. 也可以 `brew install --debug --verbose i386-jos-elf-gcc`

## build log
当使用 brew install 编译某个包出错时，Homebrew 会在终端中直接输出错误信息并提示具体的日志文件路径（通常位于专用的缓存目录下）：
macOS: ~/Library/Logs/Homebrew/<软件包名>/
Linux: $XDG_CACHE_HOME/Homebrew/Logs/<软件包名>/ 或 ~/.cache/Homebrew/Logs/<软件包名>/

## 查看依赖树
brew deps i386-jos-elf-gcc --tree

## git tap 的 pull 的路径为：
/usr/local/Homebrew/Library/Taps/dyx884877791/homebrew-i386-jos-elf-gcc/

## 高级
# 启用并行下载
export HOMEBREW_PARALLEL_DOWNLOAD=1

# 禁用自动更新（加快命令执行）
export HOMEBREW_NO_AUTO_UPDATE=1

# 显示 Homebrew 本地的 Git 仓库
$ brew --repo
: /usr/local/Homebrew

# 显示 Homebrew 安装路径
$ brew --prefix
: /usr/local

# 显示 Homebrew Cellar 路径
$ brew --cellar
: /usr/local/Cellar

# 显示 Homebrew Caskroom 路径
$ brew --caskroom
: /usr/local/Caskroom

# 缓存路径
$ brew --cache
: ~/Library/Caches/Homebrew 

## Homebrew 默认安装路径如下：

macOS ARM: /opt/homebrew
macOS Intel: /usr/local


以 brew install git 为例：

Homebrew 将 git 下载至 /usr/local/Cellar/git/<version>/ 目录下，其二进制文件在 /usr/local/Cellar/git/<version>/bin/git。

Homebrew 为 /usr/local/Cellar/git/<version>/bin/git 创建了一个软链文件至 /usr/local/bin 里。

macOS ARM 的路径对应是：

/opt/homebrew/Cellar/git/<version>/
/opt/homebrew/Cellar/git/<version>/bin/git
/opt/homebrew/bin
这也是 macOS ARM 要将 /opt/homebrew/bin 添加到 PATH 环境变量的原因。

当执行 brew uninstall 时，会将 /usr/local/Cellar 下对应包目录删除，对应的链接关系也会移除。
当执行 brew cleanup 时，会将 /usr/local/Cellar 所有包里的旧版本，只保留最新版本。

## Homebrew 常用命令
# 检查
用于检查 Homebrew 当前配置是否合理，或者某些包存在的问题等。
$ brew doctor

# 搜索
支持模糊搜索。
$ brew search <keyword>

# 更新包
$ brew upgrade                  # 更新所有已安装的包
$ brew upgrade <package-name>   # 更新指定包

# 列出已安装的包
$ brew list                     # 所有的软件，包括 Formulae  和 Cask
$ brew list --formulae          # 所有已安装的 Formulae
$ brew list --cask              # 所有已安装的 Casks
$ brew list <package-name>      # 列举某个 Formulate 或 Cask 的详细路径
$ brew list --versions          # list 默认不会直接列出版本信息，可以通过 --versions 选项来显示版本信息

# 列出可更新的包
$ brew outdated

# 锁定某个不想更新的包
$ brew pin <package-name>       # 锁定指定包
$ brew unpin <package-name>     # 取消锁定指定包

# 清理旧包
$ brew cleanup                  # 清理所有旧版本的包
$ brew cleanup <package-name>   # 清理指定的旧版本包
$ brew cleanup -n               # 查看可清理的旧版本包

# 查看已安装包的依赖
$ brew deps --installed --tree

# 查看包的信息
$ brew info <package>           # 显示某个包信息
$ brew info                     # 显示安装的软件数量、文件数量以及占用空间

